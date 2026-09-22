import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:trucaralho/application/truco/truco_game_config.dart';
import 'package:trucaralho/application/truco/truco_game_factory.dart';
import 'package:trucaralho/application/truco/truco_session.dart';
import 'package:trucaralho/core/game/persistence.dart';
import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/core/game/serialization.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/truco_action.dart';
import 'package:trucaralho/games/truco/truco_ai.dart';
import 'package:trucaralho/games/truco/truco_game.dart';
import 'package:trucaralho/games/truco/truco_rules.dart';
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

void _expectCardConservation(TrucoState state) {
  final playedCards = state.tricks
      .expand((trick) => trick.cards)
      .map((played) => played.card)
      .toList();

  final allCards = <Card>[
    ...state.deck.cards,
    state.vira,
    ...state.hands.values.expand((cards) => cards),
    ...playedCards,
  ];

  expect(allCards.length, 40);
  expect(allCards.toSet().length, 40);

  final expectedHandCards =
      state.players.length * 3 - playedCards.length;

  expect(
    state.hands.values.fold<int>(
      0,
      (total, cards) => total + cards.length,
    ),
    expectedHandCards,
  );

  expect(
    state.tricks.every(
      (trick) => trick.cards.length <= state.players.length,
    ),
    isTrue,
  );
}

void _playToTerminal(
  TrucoGame game,
  TrucoState initialState, {
  required Map<String, TrucoAI> ais,
  int maxActions = 3000,
}) {
  var state = initialState;

  for (var actionCount = 0; actionCount < maxActions; actionCount++) {
    _expectCardConservation(state);

    if (state.phase == TrucoPhase.gameFinished) {
      return;
    }

    if (state.phase == TrucoPhase.handFinished) {
      state = game.apply(state, const StartNextHand());
      continue;
    }

    final playerId = state.phase == TrucoPhase.waitingTrucoResponse
        ? state.pendingRaise!.responderId
        : state.turnPlayerId;
    final player = state.players.firstWhere(
      (candidate) => candidate.id == playerId,
    );
    final ai = ais[playerId];

    expect(ai, isNotNull);
    state = game.apply(state, ai!.chooseAction(state, player));
  }

  fail('A partida excedeu o limite de $maxActions ações.');
}

void main() {
  test('Mão de Onze em 2v2 permanece sob controle do humano', () async {
    final setup = TrucoGameFactory(
      random: Random(42),
      aiBuilder: (_) => BasicTrucoAI(random: Random(7)),
    ).create(
      TrucoGameConfig(
        mode: TrucoGameMode.twoVsTwo,
        humanName: 'Vitor',
        aiNames: const ['Bot 1', 'Bot 2', 'Bot 3'],
      ),
    );

    final pending = setup.initialState.copyWith(
      teamScores: const {'team_1': 11, 'team_2': 8},
      phase: TrucoPhase.waitingElevenDecision,
      handElevenTeamId: 'team_1',
      elevenHand: true,
    );

    final session = TrucoSession(
      initialState: pending,
      persistence: GameStatePersistence<TrucoState>(
        serializer: serializer,
        store: MemoryStore(),
        game: 'truco_paulista',
      ),
      persistenceKey: 'current',
      ais: setup.ais,
    );

    await session.resume();

    expect(session.state.phase, TrucoPhase.waitingElevenDecision);
    expect(session.state.handElevenTeamId, 'team_1');
    expect(session.history.events, isEmpty);
  });

  test('pedido de Truco pendente deve corresponder ao valor atual da mão', () {
    final game = const TrucoGame();
    final state = game.newGame(
      players: const [
        Player(id: 'p1', name: 'P1'),
        Player(id: 'p2', name: 'P2', kind: PlayerKind.ai),
      ],
      teams: const [
        Team(id: 't1', name: 'T1', playerIds: ['p1']),
        Team(id: 't2', name: 'T2', playerIds: ['p2']),
      ],
      deck: const Deck([]),
      vira: const Card(rank: Rank.seven, suit: Suit.diamonds),
      hands: const {
        'p1': [
          Card(rank: Rank.three, suit: Suit.hearts),
          Card(rank: Rank.two, suit: Suit.hearts),
          Card(rank: Rank.ace, suit: Suit.hearts),
        ],
        'p2': [
          Card(rank: Rank.four, suit: Suit.spades),
          Card(rank: Rank.five, suit: Suit.spades),
          Card(rank: Rank.six, suit: Suit.spades),
        ],
      },
      openingPlayerId: 'p1',
      dealerId: 'p2',
    ).copyWith(
      handValue: 3,
      phase: TrucoPhase.waitingTrucoResponse,
      turnPlayerId: 'p2',
      pendingRaise: const TrucoRaise(
        requesterId: 'p1',
        responderId: 'p2',
        previousValue: 1,
        requestedValue: 3,
      ),
    );

    expect(
      () => game.apply(state, const AcceptTruco('p2')),
      throwsStateError,
    );
    expect(
      () => game.apply(state, const FoldTruco('p2')),
      throwsStateError,
    );
  });

  test('partidas 1v1 e 2v2 preservam invariantes de cartas até o fim', () {
    for (var seed = 1; seed <= 10; seed++) {
      const players = [
        Player(id: 'p1', name: 'P1', kind: PlayerKind.ai),
        Player(id: 'p2', name: 'P2', kind: PlayerKind.ai),
      ];
      const teams = [
        Team(id: 't1', name: 'T1', playerIds: ['p1']),
        Team(id: 't2', name: 'T2', playerIds: ['p2']),
      ];

      final game = TrucoGame(random: Random(seed));
      final state = game.startGame(
        players: players,
        teams: teams,
        openingPlayerId: 'p1',
        dealerId: 'p2',
      );
      final random = Random(seed * 1000);

      _playToTerminal(
        game,
        state,
        ais: {
          for (final player in players)
            player.id: BasicTrucoAI(random: random),
        },
      );
    }

    for (var seed = 1; seed <= 10; seed++) {
      const players = [
        Player(id: 'a', name: 'A', kind: PlayerKind.ai),
        Player(id: 'b', name: 'B', kind: PlayerKind.ai),
        Player(id: 'c', name: 'C', kind: PlayerKind.ai),
        Player(id: 'd', name: 'D', kind: PlayerKind.ai),
      ];
      const teams = [
        Team(id: 'x', name: 'X', playerIds: ['a', 'c']),
        Team(id: 'y', name: 'Y', playerIds: ['b', 'd']),
      ];

      final game = TrucoGame(random: Random(seed));
      final state = game.startGame(
        players: players,
        teams: teams,
        openingPlayerId: 'a',
        dealerId: 'd',
      );
      final random = Random(seed * 1000);

      _playToTerminal(
        game,
        state,
        ais: {
          for (final player in players)
            player.id: BasicTrucoAI(random: random),
        },
      );
    }
  });
}
