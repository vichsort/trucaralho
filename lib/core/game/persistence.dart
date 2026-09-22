import 'serialization.dart';

final class GameStateSnapshot {
  final String game;
  final int schemaVersion;
  final DateTime savedAt;
  final Map<String, dynamic> state;

  GameStateSnapshot({
    required this.game,
    required this.schemaVersion,
    required this.savedAt,
    required Map<String, dynamic> state,
  }) : state = Map.unmodifiable(state) {
    if (game.trim().isEmpty) {
      throw ArgumentError('O identificador do jogo não pode ser vazio.');
    }
    if (schemaVersion < 1) {
      throw ArgumentError('A versão do schema deve ser positiva.');
    }
  }

  Map<String, dynamic> toJson() => {
        'game': game,
        'schemaVersion': schemaVersion,
        'savedAt': savedAt.toIso8601String(),
        'state': state,
      };

  factory GameStateSnapshot.fromJson(Map<String, dynamic> json) {
    final game = json['game'];
    final schemaVersion = json['schemaVersion'];
    final savedAt = json['savedAt'];
    final state = json['state'];

    if (game is! String ||
        schemaVersion is! int ||
        savedAt is! String ||
        state is! Map) {
      throw FormatException('Snapshot de estado inválido.');
    }

    return GameStateSnapshot(
      game: game,
      schemaVersion: schemaVersion,
      savedAt: DateTime.parse(savedAt),
      state: Map<String, dynamic>.from(state),
    );
  }
}

abstract interface class GameStateStore {
  Future<void> save(String key, GameStateSnapshot snapshot);
  Future<GameStateSnapshot?> read(String key);
  Future<void> delete(String key);
}

final class GameStatePersistence<S> {
  final StateSerializer<S> serializer;
  final GameStateStore store;
  final String game;
  final int schemaVersion;

  const GameStatePersistence({
    required this.serializer,
    required this.store,
    required this.game,
    this.schemaVersion = 1,
  });

  Future<void> save(
    String key,
    S state, {
    DateTime? savedAt,
  }) async {
    _validateKey(key);

    await store.save(
      key,
      GameStateSnapshot(
        game: game,
        schemaVersion: schemaVersion,
        savedAt: savedAt ?? DateTime.now(),
        state: serializer.serialize(state),
      ),
    );
  }

  Future<S?> restore(String key) async {
    _validateKey(key);

    final snapshot = await store.read(key);
    if (snapshot == null) {
      return null;
    }

    if (snapshot.game != game) {
      throw StateError(
        'Snapshot pertence a outro jogo: ' + snapshot.game + '.',
      );
    }
    if (snapshot.schemaVersion != schemaVersion) {
      throw StateError(
        'Schema incompatível: esperado ' +
        schemaVersion.toString() +
        ', recebido ' +
        snapshot.schemaVersion.toString() +
        '.',
      );
    }

    return serializer.deserialize(snapshot.state);
  }

  Future<void> delete(String key) async {
    _validateKey(key);
    await store.delete(key);
  }

  void _validateKey(String key) {
    if (key.trim().isEmpty) {
      throw ArgumentError('A chave do estado não pode ser vazia.');
    }
  }
}
