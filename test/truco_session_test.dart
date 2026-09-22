import 'package:test/test.dart';

import 'package:trucaralho/application/truco/truco_session.dart';
import 'package:trucaralho/core/game/persistence.dart';
import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/core/game/serialization.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';
import 'package:trucaralho/games/truco/truco_ai.dart';
import 'package:trucaralho/games/truco/truco_action.dart';
import 'package:trucaralho/games/truco/truco_game.dart';
import 'package:trucaralho/games/truco/truco_state.dart';

const p1 = Player(id: 'p1', name: 'Humano');
const p2 = Player(id: 'p2', name: 'IA', kind: PlayerKind.ai);
const t1 = Team(id: 't1', name: 'Nós', playerIds: ['p1']);
const t2 = Team(id: 't2', name: 'Eles', playerIds: ['p2']);
const vira = Card(rank: Rank.seven, suit: Suit.diamonds);

TrucoState baseState({
  Map<String, int>? scores,
  TrucoPhase phase = TrucoPhase.playing,
}) =>
    TrucoState(
      players: const [p1, p2],
      teams: const [t1, t2],
      deck: const Deck([]),
      vira: vira,
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
      tricks: const [],
      currentTrick: 1,
      turnPlayerId: 'p1',
      openingPlayerId: 'p1',
      dealerId: 'p2',
      handNumber: 1,
      teamScores: scores ?? const {'t1': 0, 't2': 0},
      handValue: 1,
      pendingRaise: null,
      phase: phase,
      handElevenTeamId: null,
      elevenHand: false,
      blindHand: false,
      handWinnerTeamId: null,
      gameWinnerTeamId: null,
    );

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

final class FixedAI implements TrucoAI {
  final TrucoAction Function(TrucoState, Player) actionBuilder;

  const FixedAI(this.actionBuilder);

  @override
  TrucoAction chooseAction(TrucoState state, Player player) =>
      actionBuilder(state, player);
}

TrucoSession session({
  required TrucoState state,
  Map<String, TrucoAI> ais = const {},
  MemoryStore? store,
}) {
  final resolvedStore = store ?? MemoryStore();
  return TrucoSession(
    initialState: state,
    persistence: GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: resolvedStore,
      game: 'truco_paulista',
    ),
    persistenceKey: 'current',
    ais: ais,
  );
}

void main() {
  test('dispatch aplica a ação, registra histórico e atualiza o estado', () async {
    final current = baseState();
    final s = session(
      state: current,
      ais: {
        'p2': FixedAI(
          (state, player) => PlayCard(
            playerId: player.id,
            card: state.hands[player.id]!.first,
          ),
        ),
      },
    );

    await s.dispatch(
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.three, suit: Suit.hearts),
      ),
    );

    expect(s.state.turnPlayerId, 'p1');
    expect(s.state.tricks.single.cards, hasLength(2));
    expect(s.history.events, hasLength(2));
    expect(s.history.events.first.type, 'play_card');
    expect(s.history.events.last.playerId, 'p2');
  });

  test('dispatch executa automaticamente a IA enquanto o próximo turno for de IA', () async {
    final current = baseState().copyWith(turnPlayerId: 'p2');
    final s = session(
      state: current,
      ais: {
        'p2': FixedAI(
          (state, player) => PlayCard(
            playerId: player.id,
            card: state.hands[player.id]!.first,
          ),
        ),
      },
    );

    await s.dispatch(const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.four, suit: Suit.spades),
    ));

    expect(s.state.turnPlayerId, 'p1');
    expect(s.history.events, hasLength(1));
  });

  test('IA responde automaticamente a um Truco pendente', () async {
    final s = session(
      state: baseState(),
      ais: {
        'p2': FixedAI(
          (state, player) => AcceptTruco(player.id),
        ),
      },
    );

    await s.dispatch(
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    expect(s.state.phase, TrucoPhase.playing);
    expect(s.state.handValue, 3);
    expect(s.state.turnPlayerId, 'p1');
    expect(s.state.pendingRaise, isNull);
    expect(s.history.events, hasLength(2));
  });

  test('IA decide Mão de Onze automaticamente', () async {
    final s = session(
      state: baseState(scores: const {'t1': 8, 't2': 11}),
      ais: {
        'p2': FixedAI(
          (state, player) => AcceptEleven(player.id),
        ),
      },
    );

    await s.resume();

    expect(s.state.phase, TrucoPhase.playing);
    expect(s.state.handValue, 3);
    expect(s.history.events, hasLength(1));
  });

  test('save e restore substituem o estado atual sem envolver Flutter', () async {
    final store = MemoryStore();
    final initial = baseState();
    final s = session(state: initial, store: store);

    await s.dispatch(
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );
    await s.save(savedAt: DateTime.utc(2026, 9, 22, 15));

    final restored = session(
      state: baseState(),
      store: store,
    );
    expect(await restored.restore(), isTrue);
    expect(restored.state.toJson(), s.state.toJson());
    expect(restored.state.pendingRaise!.requestedValue, 3);
  });

  test('restore retoma automaticamente um turno de IA pendente', () async {
    final store = MemoryStore();
    final initial = baseState();
    final source = session(state: initial, store: store);

    await source.dispatch(
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    // Persistimos manualmente o estado pendente para não deixar a IA responder antes do restore.
    final pendingStore = MemoryStore();
    await GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: pendingStore,
      game: 'truco_paulista',
    ).save(
      'current',
      source.state,
      savedAt: DateTime.utc(2026, 9, 22, 15),
    );

    final restored = session(
      state: baseState(),
      store: pendingStore,
      ais: {
        'p2': FixedAI(
          (state, player) => AcceptTruco(player.id),
        ),
      },
    );

    expect(await restored.restore(), isTrue);
    expect(restored.state.phase, TrucoPhase.playing);
    expect(restored.state.handValue, 3);
    expect(restored.state.pendingRaise, isNull);
  });

  test('save sem snapshot retorna false no restore', () async {
    final s = session(state: baseState());
    expect(await s.restore(), isFalse);
  });

  test('não permite estratégia de IA para jogador humano', () {
    expect(
      () => session(
        state: baseState(),
        ais: {
          'p1': FixedAI(
            (state, player) => PlayCard(
              playerId: player.id,
              card: state.hands[player.id]!.first,
            ),
          ),
        },
      ),
      throwsArgumentError,
    );
  });
}
