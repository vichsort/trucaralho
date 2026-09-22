import 'dart:math';

import 'package:test/test.dart';
import 'package:trucaralho/application/truco/truco_game_config.dart';
import 'package:trucaralho/application/truco/truco_game_factory.dart';
import 'package:trucaralho/core/game/persistence.dart';
import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/core/game/serialization.dart';
import 'package:trucaralho/games/truco/truco_ai.dart';
import 'package:trucaralho/games/truco/truco_state.dart';

final serializer = JsonStateSerializer<TrucoState>(
  encode: (state) => state.toJson(),
  decode: TrucoState.fromJson,
);

final class MemoryStore implements GameStateStore {
  final Map<String, GameStateSnapshot> snapshots = {};

  @override
  Future<void> save(String key, GameStateSnapshot snapshot) async {
    snapshots[key] = snapshot;
  }

  @override
  Future<GameStateSnapshot?> read(String key) async => snapshots[key];

  @override
  Future<void> delete(String key) async {
    snapshots.remove(key);
  }
}

void main() {
  test('cria partida 1v1 com humano, IA, equipes e mão inicial', () {
    final setup = TrucoGameFactory(random: Random(42)).create(
      const TrucoGameConfig(),
    );

    expect(setup.players.length, 2);
    expect(
      setup.players[0],
      const Player(
        id: 'human',
        name: 'Você',
        kind: PlayerKind.human,
      ),
    );
    expect(
      setup.players[1],
      const Player(
        id: 'ai_1',
        name: 'IA',
        kind: PlayerKind.ai,
      ),
    );
    expect(setup.teams.length, 2);
    expect(setup.teams[0].playerIds, ['human']);
    expect(setup.teams[1].playerIds, ['ai_1']);
    expect(setup.ais.keys, {'ai_1'});
    expect(setup.initialState.hands.values.every((cards) => cards.length == 3), isTrue);
    expect(setup.initialState.vira, isNotNull);
    expect(setup.initialState.deck.cards.length, 33);
    expect(setup.initialState.teamScores, {'team_1': 0, 'team_2': 0});
  });

  test('cria partida 2v2 com duas equipes de dois e três IAs', () {
    final setup = TrucoGameFactory(random: Random(42)).create(
      TrucoGameConfig(
        mode: TrucoGameMode.twoVsTwo,
        humanName: 'Vitor',
        aiNames: const ['Bot 1', 'Bot 2', 'Bot 3'],
      ),
    );

    expect(setup.players.map((player) => player.kind), [
      PlayerKind.human,
      PlayerKind.ai,
      PlayerKind.ai,
      PlayerKind.ai,
    ]);
    expect(setup.teams.map((team) => team.playerIds), [
      ['human', 'ai_2'],
      ['ai_1', 'ai_3'],
    ]);
    expect(setup.ais.keys, {'ai_1', 'ai_2', 'ai_3'});
    expect(setup.initialState.hands.length, 4);
    expect(
      setup.initialState.hands.values.every((cards) => cards.length == 3),
      isTrue,
    );
    expect(setup.initialState.deck.cards.length, 27);
  });

  test('dealer e jogador inicial respeitam a ordem da mesa', () {
    final setup = TrucoGameFactory(random: Random(42)).create(
      TrucoGameConfig(
        mode: TrucoGameMode.twoVsTwo,
        aiNames: const ['Bot 1', 'Bot 2', 'Bot 3'],
        dealerIndex: 2,
      ),
    );

    expect(setup.initialState.dealerId, 'ai_2');
    expect(setup.initialState.openingPlayerId, 'ai_3');
    expect(setup.initialState.turnPlayerId, 'ai_3');
  });

  test('Random injetado torna a mão inicial determinística', () {
    final first = TrucoGameFactory(random: Random(42)).create(
      const TrucoGameConfig(),
    );
    final second = TrucoGameFactory(random: Random(42)).create(
      const TrucoGameConfig(),
    );

    expect(first.initialState.toJson(), second.initialState.toJson());
  });

  test('AI builder personalizado controla as estratégias da partida', () {
    final setup = TrucoGameFactory(
      random: Random(42),
      aiBuilder: (_) => RandomTrucoAI(random: Random(7)),
    ).create(
      TrucoGameConfig(
        mode: TrucoGameMode.twoVsTwo,
        aiNames: const ['A', 'B', 'C'],
      ),
    );

    expect(setup.ais.values, everyElement(isA<RandomTrucoAI>()));
  });

  test('configuração rejeita quantidade de IAs incompatível com o modo', () {
    expect(
      () => TrucoGameConfig(aiNames: const ['Bot 1', 'Bot 2']),
      throwsArgumentError,
    );
    expect(
      () => TrucoGameConfig(
        mode: TrucoGameMode.twoVsTwo,
        aiNames: const ['Bot 1'],
      ),
      throwsArgumentError,
    );
  });

  test('configuração rejeita nomes vazios e dealer inválido', () {
    expect(
      () => TrucoGameConfig(humanName: ' '),
      throwsArgumentError,
    );
    expect(
      () => TrucoGameConfig(aiNames: const ['']),
      throwsArgumentError,
    );
    expect(
      () => TrucoGameConfig(dealerIndex: 2),
      throwsArgumentError,
    );
  });

  test('partida criada pode ser entregue diretamente à TrucoSession', () async {
    final store = MemoryStore();
    final setup = TrucoGameFactory(random: Random(42)).create(
      const TrucoGameConfig(),
    );
    final session = setup.createSession(
      persistence: GameStatePersistence<TrucoState>(
        serializer: serializer,
        store: store,
        game: 'truco_paulista',
      ),
      persistenceKey: 'current',
    );

    expect(session.state.toJson(), setup.initialState.toJson());
  });
}
