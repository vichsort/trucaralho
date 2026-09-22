import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:trucaralho/core/game/persistence.dart';
import 'package:trucaralho/infrastructure/persistence/file_game_state_store.dart';

GameStateSnapshot snapshot({
  String game = 'truco_paulista',
  int schemaVersion = 1,
  DateTime? savedAt,
  Map<String, dynamic> state = const <String, dynamic>{
    'phase': 'playing',
    'handValue': 3,
    'pendingRaise': null,
  },
}) =>
    GameStateSnapshot(
      game: game,
      schemaVersion: schemaVersion,
      savedAt: savedAt ?? DateTime.utc(2026, 9, 22, 16),
      state: state,
    );

void main() {
  late Directory tempDirectory;
  late FileGameStateStore store;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'trucaralho_file_store_',
    );
    store = FileGameStateStore(rootDirectory: tempDirectory);
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('salva e lê um snapshot com round-trip completo', () async {
    final original = snapshot();

    await store.save('current', original);
    final restored = await store.read('current');

    expect(restored, isNotNull);
    expect(restored!.toJson(), original.toJson());
  });

  test('cria o diretório de armazenamento no primeiro save', () async {
    final nestedDirectory = Directory(
      '${tempDirectory.path}${Platform.pathSeparator}nested${Platform.pathSeparator}saves',
    );
    final nestedStore = FileGameStateStore(rootDirectory: nestedDirectory);

    expect(await nestedDirectory.exists(), isFalse);

    await nestedStore.save('current', snapshot());

    expect(await nestedDirectory.exists(), isTrue);
  });

  test('chaves diferentes permanecem isoladas', () async {
    final first = snapshot(state: const <String, dynamic>{'value': 1});
    final second = snapshot(state: const <String, dynamic>{'value': 2});

    await store.save('first', first);
    await store.save('second', second);

    expect((await store.read('first'))!.state['value'], 1);
    expect((await store.read('second'))!.state['value'], 2);
  });

  test('chave arbitrária não cria caminho fora do diretório', () async {
    const key = '../current/../saved state';
    final original = snapshot();

    await store.save(key, original);
    final restored = await store.read(key);

    expect(restored!.toJson(), original.toJson());
    expect(
      await File(
        '${tempDirectory.parent.path}${Platform.pathSeparator}saved state.snapshot.json',
      ).exists(),
      isFalse,
    );
  });

  test('ler chave inexistente retorna null', () async {
    expect(await store.read('missing'), isNull);
  });

  test('delete remove o snapshot e é idempotente', () async {
    await store.save('current', snapshot());

    await store.delete('current');
    await store.delete('current');

    expect(await store.read('current'), isNull);
  });

  test('chave vazia é rejeitada em todas as operações', () async {
    expect(() => store.save('', snapshot()), throwsArgumentError);
    expect(() => store.read(' '), throwsArgumentError);
    expect(() => store.delete('\t'), throwsArgumentError);
  });

  test('snapshot JSON corrompido gera FormatException', () async {
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}Y29ycnVwdA.snapshot.json',
    );
    await tempDirectory.create(recursive: true);
    await file.writeAsString('{not-json');

    expect(
      () => store.read('corrupt'),
      throwsA(isA<FormatException>()),
    );
  });

  test('JSON válido mas snapshot inválido também é rejeitado', () async {
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}aW52YWxpZA.snapshot.json',
    );
    await file.writeAsString(jsonEncode(<String, dynamic>{
      'game': 'truco_paulista',
    }));

    expect(
      () => store.read('invalid'),
      throwsA(isA<FormatException>()),
    );
  });
}
