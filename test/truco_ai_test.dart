import 'dart:math';

import 'package:test/test.dart';

import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';
import 'package:trucaralho/games/truco/truco_action.dart';
import 'package:trucaralho/games/truco/truco_ai.dart';
import 'package:trucaralho/games/truco/truco_game.dart';
import 'package:trucaralho/games/truco/truco_state.dart';

const p1 = Player(id: 'p1', name: 'P1');
const p2 = Player(id: 'p2', name: 'P2', kind: PlayerKind.ai);
const t1 = Team(id: 't1', name: 'T1', playerIds: ['p1']);
const t2 = Team(id: 't2', name: 'T2', playerIds: ['p2']);
const vira = Card(rank: Rank.seven, suit: Suit.diamonds);

TrucoState base({
  int handValue = 1,
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
    ).copyWith(handValue: handValue);

class ScriptedRandom implements Random {
  final int value;

  ScriptedRandom(this.value);

  @override
  bool nextBool() => value.isOdd;

  @override
  double nextDouble() => value == 0 ? 0.0 : 0.99;

  @override
  int nextInt(int max) => value % max;
}

void main() {
  const game = TrucoGame();

  test('IA básica exige controlar um jogador marcado como IA', () {
    expect(
      () => BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
        base(),
        p1,
      ),
      throwsArgumentError,
    );
  });

  test('IA básica não age fora da sua vez', () {
    expect(
      () => BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
        base(),
        p2,
      ),
      throwsStateError,
    );
  });

  test('IA básica pede Truco quando a mão é forte', () {
    final state = base(
      openingPlayerId: 'p2',
      dealerId: 'p1',
      p2Cards: const [
        Card(rank: Rank.three, suit: Suit.spades),
        Card(rank: Rank.two, suit: Suit.spades),
        Card(rank: Rank.ace, suit: Suit.spades),
      ],
    );

    final action = BasicTrucoAI(random: ScriptedRandom(0)).chooseAction(
      state,
      p2,
    );

    expect(action, isA<RequestTruco>());
    expect((action as RequestTruco).requestedValue, 3);
    expect(() => game.apply(state, action), returnsNormally);
  });

  test('IA básica responde ao pedido com ação aplicável ao engine', () {
    final requested = game.apply(
      base(),
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    final action = BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
      requested,
      p2,
    );

    expect(
      action is AcceptTruco || action is FoldTruco || action is RaiseTruco,
      isTrue,
    );
    expect(() => game.apply(requested, action), returnsNormally);
  });

  test('IA básica fraca corre de um Truco', () {
    final requested = game.apply(
      base(
        p2Cards: const [
          Card(rank: Rank.four, suit: Suit.spades),
          Card(rank: Rank.five, suit: Suit.spades),
          Card(rank: Rank.six, suit: Suit.spades),
        ],
      ),
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    final action = BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
      requested,
      p2,
    );

    expect(action, isA<FoldTruco>());
    final result = game.apply(requested, action);
    expect(result.teamScores['t1'], 1);
  });

  test('IA básica aceita Mão de Onze com mão forte', () {
    final state = base(
      scores: const {'t1': 8, 't2': 11},
      p2Cards: const [
        Card(rank: Rank.three, suit: Suit.spades),
        Card(rank: Rank.two, suit: Suit.spades),
        Card(rank: Rank.ace, suit: Suit.spades),
      ],
    );

    final action = BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
      state,
      p2,
    );

    expect(action, isA<AcceptEleven>());
    expect(() => game.apply(state, action), returnsNormally);
  });

  test('IA básica recusa Mão de Onze com mão fraca', () {
    final state = base(
      scores: const {'t1': 8, 't2': 11},
    );

    final action = BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
      state,
      p2,
    );

    expect(action, isA<FoldEleven>());
    final result = game.apply(state, action);
    expect(result.teamScores['t1'], 9);
  });

  test('IA básica não joga carta quando é respondente de Truco', () {
    final requested = game.apply(
      base(),
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    final action = BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
      requested,
      p2,
    );

    expect(action, isNot(isA<PlayCard>()));
    expect(() => game.apply(requested, action), returnsNormally);
  });

  test('IA básica rejeita agir em uma negociação da qual não é respondente', () {
    final requested = game.apply(
      base(),
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    expect(
      () => BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
        requested,
        p1,
      ),
      throwsArgumentError,
    );
  });

  test('IA básica escolhe a menor carta vencedora quando o adversário lidera', () {
    final state = base(
      p2Cards: const [
        Card(rank: Rank.five, suit: Suit.spades),
        Card(rank: Rank.two, suit: Suit.spades),
        Card(rank: Rank.three, suit: Suit.spades),
      ],
    );

    var afterOpponent = game.apply(
      state,
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.two, suit: Suit.hearts),
      ),
    );

    final action = BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
      afterOpponent,
      p2,
    );

    expect(action, isA<PlayCard>());
    expect(
      (action as PlayCard).card,
      const Card(rank: Rank.three, suit: Suit.spades),
    );
    afterOpponent = game.apply(afterOpponent, action);
    expect(afterOpponent.tricks.single.winnerId, 'p2');
  });

  test('IA básica descarta a menor carta quando seu parceiro já está ganhando', () {
    const a = Player(id: 'a', name: 'A');
    const b = Player(id: 'b', name: 'B', kind: PlayerKind.ai);
    const c = Player(id: 'c', name: 'C', kind: PlayerKind.ai);
    const d = Player(id: 'd', name: 'D', kind: PlayerKind.ai);
    const x = Team(id: 'x', name: 'X', playerIds: ['a', 'c']);
    const y = Team(id: 'y', name: 'Y', playerIds: ['b', 'd']);

    var state = const TrucoGame().newGame(
      players: [a, b, c, d],
      teams: [x, y],
      deck: Deck(const []),
      vira: vira,
      hands: const {
        'a': [
          Card(rank: Rank.three, suit: Suit.hearts),
          Card(rank: Rank.four, suit: Suit.hearts),
          Card(rank: Rank.five, suit: Suit.hearts),
        ],
        'b': [
          Card(rank: Rank.six, suit: Suit.spades),
          Card(rank: Rank.queen, suit: Suit.spades),
          Card(rank: Rank.king, suit: Suit.spades),
        ],
        'c': [
          Card(rank: Rank.four, suit: Suit.diamonds),
          Card(rank: Rank.five, suit: Suit.diamonds),
          Card(rank: Rank.six, suit: Suit.diamonds),
        ],
        'd': [
          Card(rank: Rank.ace, suit: Suit.clubs),
          Card(rank: Rank.two, suit: Suit.clubs),
          Card(rank: Rank.queen, suit: Suit.clubs),
        ],
      },
      openingPlayerId: 'a',
      dealerId: 'd',
    );

    state = game.apply(
      state,
      const PlayCard(
        playerId: 'a',
        card: Card(rank: Rank.three, suit: Suit.hearts),
      ),
    );
    state = game.apply(
      state,
      const PlayCard(
        playerId: 'b',
        card: Card(rank: Rank.six, suit: Suit.spades),
      ),
    );

    final action = BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(
      state,
      c,
    );

    expect(action, isA<PlayCard>());
    expect(
      (action as PlayCard).card,
      const Card(rank: Rank.four, suit: Suit.diamonds),
    );
    expect(() => game.apply(state, action), returnsNormally);
  });

  test('IA aleatória sempre devolve ação válida durante uma jogada', () {
    var state = base(
      openingPlayerId: 'p2',
      dealerId: 'p1',
      p2Cards: const [
        Card(rank: Rank.four, suit: Suit.spades),
        Card(rank: Rank.five, suit: Suit.spades),
        Card(rank: Rank.six, suit: Suit.spades),
      ],
    );

    final ai = RandomTrucoAI(random: ScriptedRandom(99));
    final action = ai.chooseAction(state, p2);

    expect(() => game.apply(state, action), returnsNormally);
    state = game.apply(state, action);
    expect(state.hands['p2']!.length, lessThan(3));
  });

  test('IA aleatória sempre devolve resposta válida a Truco', () {
    final state = game.apply(
      base(),
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    final action = RandomTrucoAI(random: ScriptedRandom(0)).chooseAction(
      state,
      p2,
    );

    expect(
      action is AcceptTruco || action is FoldTruco || action is RaiseTruco,
      isTrue,
    );
    expect(() => game.apply(state, action), returnsNormally);
  });

  test('IA aleatória sempre devolve decisão válida de Mão de Onze', () {
    final state = base(scores: const {'t1': 8, 't2': 11});
    final action = RandomTrucoAI(random: ScriptedRandom(1)).chooseAction(
      state,
      p2,
    );

    expect(
      action is AcceptEleven || action is FoldEleven,
      isTrue,
    );
    expect(() => game.apply(state, action), returnsNormally);
  });

  test('IA não age em partida encerrada', () {
    final state = base().copyWith(
      phase: TrucoPhase.gameFinished,
      gameWinnerTeamId: 't1',
    );

    expect(
      () => BasicTrucoAI(random: ScriptedRandom(99)).chooseAction(state, p2),
      throwsStateError,
    );
    expect(
      () => RandomTrucoAI(random: ScriptedRandom(99)).chooseAction(state, p2),
      throwsStateError,
    );
  });
}
