import 'dart:convert';
import 'dart:io';

import '../../core/game/persistence.dart';

final class FileGameStateStore implements GameStateStore {
  final Directory rootDirectory;

  const FileGameStateStore({
    required this.rootDirectory,
  });

  @override
  Future<void> save(String key, GameStateSnapshot snapshot) async {
    _validateKey(key);
    await rootDirectory.create(recursive: true);

    final file = _fileForKey(key);
    final encoded = jsonEncode(snapshot.toJson());
    await file.writeAsString(encoded, flush: true);
  }

  @override
  Future<GameStateSnapshot?> read(String key) async {
    _validateKey(key);

    final file = _fileForKey(key);
    if (!await file.exists()) {
      return null;
    }

    final content = await file.readAsString();

    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        throw const FormatException('Snapshot persistido não é um objeto JSON.');
      }

      return GameStateSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException(
        'Não foi possível ler o snapshot persistido: $error',
      );
    }
  }

  @override
  Future<void> delete(String key) async {
    _validateKey(key);

    final file = _fileForKey(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  File _fileForKey(String key) {
    final encodedKey = base64Url
        .encode(utf8.encode(key))
        .replaceAll('=', '');

    return File(
      '${rootDirectory.path}${Platform.pathSeparator}$encodedKey.snapshot.json',
    );
  }

  void _validateKey(String key) {
    if (key.trim().isEmpty) {
      throw ArgumentError('A chave do estado não pode ser vazia.');
    }
  }
}
