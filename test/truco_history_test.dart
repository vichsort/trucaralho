import 'package:test/test.dart';
import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';
import 'package:trucaralho/games/truco/truco_action.dart';
import 'package:trucaralho/games/truco/truco_game.dart';
import 'package:trucaralho/games/truco/truco_history.dart';
import 'package:trucaralho/games/truco/truco_state.dart';

const p1 = Player(id: 'p1', name: 'P1');
const p2 = Player(id: 'p2', name: 'P2', kind: PlayerKind.ai);
const t1 = Team(id: 't1', name: 'Nós', playerIds: ['p1']);
const t2 = Team(id: 't2', name: 'Eles', playerIds: ['p2']);
const vira = Card(rank: Rank.seven, suit: Suit.diamonds);

TrucoState stateWith({
  Map<String, int>? scores,
  String openingPlayerId = 'p1',
  String dealerId = 'p2',
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
      openingPlayerId: openingPlayerId,
      dealerId: dealerId,
      scores: scores,
    );

void main() {
  final fixedStart = DateTime.utc(2026, 9, 22, 14);
  final fixedEnd = DateTime.utc(2026, 9, 22, 14, 1);
  const game = TrucoGame();

  test('registra fold de Truco com valor solicitado e valor efetivamente ganho', () {
    final initial = stateWith();
    final recorder = TrucoHistoryRecorder(
      initialState: initial,
      startedAt: fixedStart,
    );

    final requested = game.apply(
      initial,
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );
    recorder.record(
      before: initial,
      action: const RequestTruco(playerId: 'p1', requestedValue: 3),
      after: requested,
      at: fixedStart.add(const Duration(seconds: 1)),
    );

    final finished = game.apply(
      requested,
      const FoldTruco('p2'),
    );
    recorder.record(
      before: requested,
      action: const FoldTruco('p2'),
      after: finished,
      at: fixedStart.add(const Duration(seconds: 2)),
    );

    final history = recorder.build(finishedAt: fixedEnd);
    expect(history.hands, hasLength(1));
    expect(history.hands.single.startingScore, {'t1': 0, 't2': 0});
    expect(history.hands.single.endingScore, {'t1': 1, 't2': 0});
    expect(history.hands.single.startingValue, 1);
    expect(history.hands.single.handValue, 1);
    expect(history.hands.single.winnerTeamId, 't1');
    expect(history.hands.single.outcome, 'truco_fold');

    final foldEvent = history.events.last;
    expect(foldEvent.type, 'fold_truco');
    expect(foldEvent.fromValue, 1);
    expect(foldEvent.toValue, 1);
    expect(foldEvent.data['requestedValue'], 3);
    expect(foldEvent.data['awardedValue'], 1);
    expect(foldEvent.data['winnerTeamId'], 't1');
  });

  test('registra cadeia de Truco, aumento e aceite sem confundir valor atual com valor pedido', () {
    final initial = stateWith();
    final recorder = TrucoHistoryRecorder(
      initialState: initial,
      startedAt: fixedStart,
    );

    final requested = game.apply(
      initial,
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );
    recorder.record(
      before: initial,
      action: const RequestTruco(playerId: 'p1', requestedValue: 3),
      after: requested,
      at: fixedStart.add(const Duration(seconds: 1)),
    );

    final raised = game.apply(
      requested,
      const RaiseTruco(playerId: 'p2', requestedValue: 6),
    );
    recorder.record(
      before: requested,
      action: const RaiseTruco(playerId: 'p2', requestedValue: 6),
      after: raised,
      at: fixedStart.add(const Duration(seconds: 2)),
    );

    final accepted = game.apply(
      raised,
      const AcceptTruco('p1'),
    );
    recorder.record(
      before: raised,
      action: const AcceptTruco('p1'),
      after: accepted,
      at: fixedStart.add(const Duration(seconds: 3)),
    );

    final history = recorder.build();
    expect(history.events, hasLength(3));
    expect(history.events[0].data['requestedValue'], 3);
    expect(history.events[0].toValue, 1);
    expect(history.events[1].data['previousValue'], 3);
    expect(history.events[1].data['requestedValue'], 6);
    expect(history.events[1].fromValue, 1);
    expect(history.events[1].toValue, 1);
    expect(history.events[2].data['acceptedValue'], 6);
    expect(history.events[2].fromValue, 1);
    expect(history.events[2].toValue, 6);
  });

  test('captura uma mão encerrada por vazas com cartas e sequência dos eventos', () {
    var state = stateWith();
    final initial = state;
    final recorder = TrucoHistoryRecorder(
      initialState: initial,
      startedAt: fixedStart,
    );

    const actions = <TrucoAction>[
      PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.three, suit: Suit.hearts),
      ),
      PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.four, suit: Suit.spades),
      ),
      PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.two, suit: Suit.hearts),
      ),
      PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.five, suit: Suit.spades),
      ),
    ];

    for (var i = 0; i < actions.length; i++) {
      final before = state;
      state = game.apply(state, actions[i]);
      recorder.record(
        before: before,
        action: actions[i],
        after: state,
        at: fixedStart.add(Duration(seconds: i + 1)),
      );
    }

    final history = recorder.build(finishedAt: fixedEnd);
    expect(state.phase, TrucoPhase.handFinished);
    expect(history.hands, hasLength(1));
    expect(history.hands.single.outcome, 'tricks');
    expect(history.hands.single.winnerTeamId, 't1');
    expect(history.hands.single.endingScore, {'t1': 1, 't2': 0});
    expect(history.hands.single.tricks, hasLength(2));
    expect(history.hands.single.tricks.first.cards, hasLength(2));
    expect(
      history.hands.single.tricks.first.cards.first.card,
      const Card(rank: Rank.three, suit: Suit.hearts),
    );
    expect(history.events.every((event) => event.handNumber == 1), isTrue);
    expect(
      history.events.every((event) => event.at.isAfter(fixedStart)),
      isTrue,
    );
  });

  test('preserva empate de três vazas como mão sem vencedor e sem pontuação', () {
    var state = stateWith(
      p1Cards: const [
        Card(rank: Rank.four, suit: Suit.diamonds),
        Card(rank: Rank.five, suit: Suit.diamonds),
        Card(rank: Rank.six, suit: Suit.diamonds),
      ],
      p2Cards: const [
        Card(rank: Rank.four, suit: Suit.spades),
        Card(rank: Rank.five, suit: Suit.spades),
        Card(rank: Rank.six, suit: Suit.spades),
      ],
    );
    final recorder = TrucoHistoryRecorder(
      initialState: state,
      startedAt: fixedStart,
    );

    final pairs = [
      const (
        Card(rank: Rank.four, suit: Suit.diamonds),
        Card(rank: Rank.four, suit: Suit.spades),
      ),
      const (
        Card(rank: Rank.five, suit: Suit.diamonds),
        Card(rank: Rank.five, suit: Suit.spades),
      ),
      const (
        Card(rank: Rank.six, suit: Suit.diamonds),
        Card(rank: Rank.six, suit: Suit.spades),
      ),
    ];

    var second = 0;
    for (final pair in pairs) {
      for (final card in [pair.$1, pair.$2]) {
        final before = state;
        final action = PlayCard(
          playerId: state.turnPlayerId,
          card: card,
        );
        state = game.apply(state, action);
        recorder.record(
          before: before,
          action: action,
          after: state,
          at: fixedStart.add(Duration(seconds: ++second)),
        );
      }
    }

    final history = recorder.build(finishedAt: fixedEnd);
    expect(state.phase, TrucoPhase.handFinished);
    expect(history.hands.single.outcome, 'tricks_tied');
    expect(history.hands.single.winnerTeamId, isNull);
    expect(history.hands.single.endingScore, {'t1': 0, 't2': 0});
    expect(history.hands.single.tricks, hasLength(3));
    expect(
      history.hands.single.tricks.every((trick) => trick.tied),
      isTrue,
    );
  });

  test('inicia o registro da próxima mão no evento StartNextHand', () {
    final initial = stateWith();
    final recorder = TrucoHistoryRecorder(
      initialState: initial,
      startedAt: fixedStart,
    );

    var state = game.apply(
      initial,
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );
    recorder.record(
      before: initial,
      action: const RequestTruco(playerId: 'p1', requestedValue: 3),
      after: state,
      at: fixedStart.add(const Duration(seconds: 1)),
    );

    final beforeFold = state;
    state = game.apply(state, const FoldTruco('p2'));
    recorder.record(
      before: beforeFold,
      action: const FoldTruco('p2'),
      after: state,
      at: fixedStart.add(const Duration(seconds: 2)),
    );

    final next = game.apply(state, const StartNextHand());
    recorder.record(
      before: state,
      action: const StartNextHand(),
      after: next,
      at: fixedStart.add(const Duration(seconds: 3)),
    );

    final history = recorder.build();
    expect(history.hands, hasLength(1));
    final startEvent = history.events.last;
    expect(startEvent.handNumber, 1);
    expect(startEvent.type, 'start_next_hand');
    expect(startEvent.data['dealerId'], 'p1');
    expect(startEvent.data['openingPlayerId'], 'p2');
  });

  test('histórico completo faz round-trip por JSON', () {
    final initial = stateWith();
    final recorder = TrucoHistoryRecorder(
      initialState: initial,
      startedAt: fixedStart,
    );

    final requested = game.apply(
      initial,
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );
    recorder.record(
      before: initial,
      action: const RequestTruco(playerId: 'p1', requestedValue: 3),
      after: requested,
      at: fixedStart.add(const Duration(seconds: 1)),
    );

    final finished = game.apply(requested, const FoldTruco('p2'));
    recorder.record(
      before: requested,
      action: const FoldTruco('p2'),
      after: finished,
      at: fixedStart.add(const Duration(seconds: 2)),
    );

    final history = recorder.build(finishedAt: fixedEnd);
    final restored = TrucoMatchHistory.fromJson(history.toJson());

    expect(restored.game, history.game);
    expect(restored.schemaVersion, 1);
    expect(restored.startedAt, history.startedAt);
    expect(restored.finishedAt, history.finishedAt);
    expect(restored.players, history.players);
    expect(
      restored.teams.map((team) => team.toJson()),
      history.teams.map((team) => team.toJson()),
    );
    expect(restored.finalScore, history.finalScore);
    expect(restored.hands.single.toJson(), history.hands.single.toJson());
    expect(
      restored.events.map((event) => event.toJson()),
      history.events.map((event) => event.toJson()),
    );
  });
}
