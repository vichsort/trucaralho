import 'package:test/test.dart';

import 'package:trucaralho/core/game/persistence.dart';
import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/core/game/serialization.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';
import 'package:trucaralho/games/truco/truco_action.dart';
import 'package:trucaralho/games/truco/truco_game.dart';
import 'package:trucaralho/games/truco/truco_state.dart';

const p1 = Player(id: 'p1', name: 'P1');
const p2 = Player(id: 'p2', name: 'P2', kind: PlayerKind.ai);
const t1 = Team(id: 't1', name: 'Nós', playerIds: ['p1']);
const t2 = Team(id: 't2', name: 'Eles', playerIds: ['p2']);
const vira = Card(rank: Rank.seven, suit: Suit.diamonds);

TrucoState base({
  Map<String, int>? scores,
  List<Card> p1Cards = const [
    Card(rank: Rank.three, suit: Suit.hearts),
    Card(rank: Rank.two, suit: Suit.hearts),
    Card(rank: Rank.ace, suit: Suit.hearts),
  ],
  List<Card> p2Cards = const [
    Card(rank: Rank.four, suit: Suit.spades),
    Card(rank: Rank.five, suit: Suit.spades),
    Card(rank: Rank.six, suit: Suit.spades),
  ],
}) =>
    const TrucoGame().newGame(
      players: [p1, p2],
      teams: [t1, t2],
      deck: Deck(const []),
      vira: vira,
      hands: {
        'p1': p1Cards,
        'p2': p2Cards,
      },
      openingPlayerId: 'p1',
      dealerId: 'p2',
      scores: scores,
    );

final class MemoryGameStateStore implements GameStateStore {
  final Map<String, GameStateSnapshot> _snapshots = {};

  @override
  Future<void> save(String key, GameStateSnapshot snapshot) async {
    _snapshots[key] = GameStateSnapshot.fromJson(snapshot.toJson());
  }

  @override
  Future<GameStateSnapshot?> read(String key) async {
    final snapshot = _snapshots[key];
    return snapshot == null
        ? null
        : GameStateSnapshot.fromJson(snapshot.toJson());
  }

  @override
  Future<void> delete(String key) async {
    _snapshots.remove(key);
  }

  void seed(GameStateSnapshot snapshot, {String key = 'game'}) {
    _snapshots[key] = GameStateSnapshot.fromJson(snapshot.toJson());
  }
}

void main() {
  final fixedAt = DateTime.utc(2026, 9, 22, 15);
  final serializer = JsonStateSerializer<TrucoState>(
    encode: (state) => state.toJson(),
    decode: TrucoState.fromJson,
  );

  test('snapshot de estado é independente do histórico e tem envelope versionado', () {
    final state = base();
    final snapshot = GameStateSnapshot(
      game: 'truco_paulista',
      schemaVersion: 1,
      savedAt: fixedAt,
      state: serializer.serialize(state),
    );

    final restored = GameStateSnapshot.fromJson(snapshot.toJson());

    expect(restored.game, 'truco_paulista');
    expect(restored.schemaVersion, 1);
    expect(restored.savedAt, fixedAt);
    expect(restored.state, state.toJson());
    expect(restored.state.containsKey('events'), isFalse);
    expect(restored.state.containsKey('hands'), isTrue);
  });

  test('persistência salva e restaura partida durante uma vaza', () async {
    final store = MemoryGameStateStore();
    final persistence = GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: store,
      game: 'truco_paulista',
    );

    final initial = base();
    final played = const TrucoGame().apply(
      initial,
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.three, suit: Suit.hearts),
      ),
    );

    await persistence.save('current', played, savedAt: fixedAt);
    final restored = await persistence.restore('current');

    expect(restored, isNotNull);
    expect(restored!.toJson(), played.toJson());
    expect(restored.turnPlayerId, 'p2');
    expect(restored.tricks.single.cards.single.playerId, 'p1');
    expect(
      () => const TrucoGame().apply(
        restored,
        const PlayCard(
          playerId: 'p2',
          card: Card(rank: Rank.four, suit: Suit.spades),
        ),
      ),
      returnsNormally,
    );
  });

  test('persistência mantém negociação de Truco pendente após restauração', () async {
    final store = MemoryGameStateStore();
    final persistence = GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: store,
      game: 'truco_paulista',
    );

    final initial = base();
    final pending = const TrucoGame().apply(
      initial,
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    await persistence.save('current', pending, savedAt: fixedAt);
    final restored = await persistence.restore('current');

    expect(restored!.phase, TrucoPhase.waitingTrucoResponse);
    expect(restored.pendingRaise!.requesterId, 'p1');
    expect(restored.pendingRaise!.responderId, 'p2');
    expect(restored.pendingRaise!.previousValue, 1);
    expect(restored.pendingRaise!.requestedValue, 3);

    final accepted = const TrucoGame().apply(
      restored,
      const AcceptTruco('p2'),
    );
    expect(accepted.handValue, 3);
    expect(accepted.turnPlayerId, 'p1');
    expect(accepted.pendingRaise, isNull);
  });

  test('persistência mantém Mão de Onze pendente após restauração', () async {
    final store = MemoryGameStateStore();
    final persistence = GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: store,
      game: 'truco_paulista',
    );

    final state = base(scores: const {'t1': 11, 't2': 8});

    await persistence.save('current', state, savedAt: fixedAt);
    final restored = await persistence.restore('current');

    expect(restored!.phase, TrucoPhase.waitingElevenDecision);
    expect(restored.handElevenTeamId, 't1');

    final accepted = const TrucoGame().apply(
      restored,
      const AcceptEleven('p1'),
    );
    expect(accepted.phase, TrucoPhase.playing);
    expect(accepted.handValue, 3);
  });

  test('persistência restaura estado terminal sem transformá-lo em nova partida', () async {
    final store = MemoryGameStateStore();
    final persistence = GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: store,
      game: 'truco_paulista',
    );

    final terminal = base(scores: const {'t1': 11, 't2': 0}).copyWith(
      phase: TrucoPhase.gameFinished,
      teamScores: const {'t1': 12, 't2': 0},
      gameWinnerTeamId: 't1',
      handWinnerTeamId: 't1',
    );

    await persistence.save('current', terminal, savedAt: fixedAt);
    final restored = await persistence.restore('current');

    expect(restored!.phase, TrucoPhase.gameFinished);
    expect(restored.gameWinnerTeamId, 't1');
    expect(restored.teamScores, {'t1': 12, 't2': 0});
    expect(restored.toJson(), terminal.toJson());
    expect(
      () => const TrucoGame().apply(restored, const StartNextHand()),
      throwsStateError,
    );
  });

  test('restore ausente retorna null e delete remove o snapshot', () async {
    final store = MemoryGameStateStore();
    final persistence = GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: store,
      game: 'truco_paulista',
    );

    expect(await persistence.restore('missing'), isNull);

    await persistence.save('current', base(), savedAt: fixedAt);
    expect(await persistence.restore('current'), isNotNull);

    await persistence.delete('current');
    expect(await persistence.restore('current'), isNull);
  });

  test('restore rejeita jogo diferente ou schema incompatível', () async {
    final store = MemoryGameStateStore();
    final persistence = GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: store,
      game: 'truco_paulista',
    );

    final state = base();
    await persistence.save('current', state, savedAt: fixedAt);

    store.seed(
      GameStateSnapshot(
        game: 'blackjack',
        schemaVersion: 1,
        savedAt: fixedAt,
        state: state.toJson(),
      ),
    );
    expect(
      () => persistence.restore('game'),
      throwsStateError,
    );

    store.seed(
      GameStateSnapshot(
        game: 'truco_paulista',
        schemaVersion: 2,
        savedAt: fixedAt,
        state: state.toJson(),
      ),
    );
    expect(
      () => persistence.restore('game'),
      throwsStateError,
    );
  });

  test('save e restore rejeitam chave vazia', () async {
    final persistence = GameStatePersistence<TrucoState>(
      serializer: serializer,
      store: MemoryGameStateStore(),
      game: 'truco_paulista',
    );

    expect(
      () => persistence.save('', base(), savedAt: fixedAt),
      throwsArgumentError,
    );
    expect(
      () => persistence.restore('  '),
      throwsArgumentError,
    );
    expect(
      () => persistence.delete(''),
      throwsArgumentError,
    );
  });

  test('snapshot rejeita schema e jogo inválidos', () {
    expect(
      () => GameStateSnapshot(
        game: '',
        schemaVersion: 1,
        savedAt: fixedAt,
        state: const {},
      ),
      throwsArgumentError,
    );
    expect(
      () => GameStateSnapshot(
        game: 'truco_paulista',
        schemaVersion: 0,
        savedAt: fixedAt,
        state: const {},
      ),
      throwsArgumentError,
    );
    expect(
      () => GameStateSnapshot.fromJson(const {
        'game': 'truco_paulista',
        'schemaVersion': 1,
        'savedAt': 'invalid',
        'state': {},
      }),
      throwsFormatException,
    );
  });
}
