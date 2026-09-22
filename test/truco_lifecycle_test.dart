import 'dart:math';

import 'package:test/test.dart';
import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';
import 'package:trucaralho/games/truco/truco_action.dart';
import 'package:trucaralho/games/truco/truco_game.dart';
import 'package:trucaralho/games/truco/truco_state.dart';

void main() {
  const p1 = Player(id: 'p1', name: 'P1');
  const p2 = Player(id: 'p2', name: 'P2', kind: PlayerKind.ai);
  const t1 = Team(id: 't1', name: 'Nós', playerIds: ['p1']);
  const t2 = Team(id: 't2', name: 'Eles', playerIds: ['p2']);

  TrucoState base({
    Map<String, int>? scores,
    List<Card>? p1Cards,
    List<Card>? p2Cards,
  }) =>
      const TrucoGame().newGame(
        players: [p1, p2],
        teams: [t1, t2],
        deck: Deck(const []),
        vira: const Card(rank: Rank.seven, suit: Suit.diamonds),
        hands: {
          'p1': [
            Card(rank: Rank.three, suit: Suit.diamonds),
            Card(rank: Rank.two, suit: Suit.diamonds),
            Card(rank: Rank.ace, suit: Suit.diamonds),
          ],
          'p2': [
            Card(rank: Rank.four, suit: Suit.diamonds),
            Card(rank: Rank.five, suit: Suit.diamonds),
            Card(rank: Rank.six, suit: Suit.diamonds),
          ],
        },
        openingPlayerId: 'p1',
        dealerId: 'p2',
        scores: scores,
      ).copyWith(
        hands: {
          'p1': p1Cards ??
              const [
                Card(rank: Rank.three, suit: Suit.diamonds),
                Card(rank: Rank.two, suit: Suit.diamonds),
                Card(rank: Rank.ace, suit: Suit.diamonds),
              ],
          'p2': p2Cards ??
              const [
                Card(rank: Rank.four, suit: Suit.diamonds),
                Card(rank: Rank.five, suit: Suit.diamonds),
                Card(rank: Rank.six, suit: Suit.diamonds),
              ],
        },
      );

  test('Mão de Onze aguarda decisão e aceite fixa 3 pontos', () {
    final s = base(scores: {'t1': 11, 't2': 8});
    expect(s.phase, TrucoPhase.waitingElevenDecision);
    expect(s.handElevenTeamId, 't1');

    final accepted =
        const TrucoGame().apply(s, const AcceptEleven('p1'));

    expect(accepted.phase, TrucoPhase.playing);
    expect(accepted.handValue, 3);
    expect(accepted.handElevenTeamId, isNull);
    expect(
      () => const TrucoGame().apply(
        accepted,
        const RequestTruco(playerId: 'p1', requestedValue: 6),
      ),
      throwsStateError,
    );
  });

  test('Mão de Onze recusada entrega 1 ponto aos adversários', () {
    final s = base(scores: {'t1': 11, 't2': 8});

    final folded =
        const TrucoGame().apply(s, const FoldEleven('p1'));

    expect(folded.phase, TrucoPhase.handFinished);
    expect(folded.teamScores['t1'], 11);
    expect(folded.teamScores['t2'], 9);
  });

  test('Mão de Ferro começa valendo 1 e não permite Truco', () {
    final s = base(scores: {'t1': 11, 't2': 11});

    expect(s.phase, TrucoPhase.playing);
    expect(s.blindHand, isTrue);
    expect(s.handValue, 1);

    expect(
      () => const TrucoGame().apply(
        s,
        const RequestTruco(playerId: 'p1', requestedValue: 3),
      ),
      throwsStateError,
    );
  });

  test('Mão de Ferro vencida encerra a partida', () {
    final s = base(
      scores: {'t1': 11, 't2': 11},
      p1Cards: const [
        Card(rank: Rank.three, suit: Suit.diamonds),
        Card(rank: Rank.two, suit: Suit.diamonds),
        Card(rank: Rank.ace, suit: Suit.diamonds),
      ],
      p2Cards: const [
        Card(rank: Rank.four, suit: Suit.diamonds),
        Card(rank: Rank.five, suit: Suit.diamonds),
        Card(rank: Rank.six, suit: Suit.diamonds),
      ],
    );

    var next = s;
    next = const TrucoGame().apply(
      next,
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.three, suit: Suit.diamonds),
      ),
    );
    next = const TrucoGame().apply(
      next,
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.four, suit: Suit.diamonds),
      ),
    );
    next = const TrucoGame().apply(
      next,
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.two, suit: Suit.diamonds),
      ),
    );
    next = const TrucoGame().apply(
      next,
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.five, suit: Suit.diamonds),
      ),
    );

    expect(next.phase, TrucoPhase.gameFinished);
    expect(next.teamScores['t1'], 12);
    expect(next.gameWinnerTeamId, 't1');
  });

  test('próxima mão gira distribuidor e mão', () {
    final game = TrucoGame(random: Random(42));
    var s = base();

    s = game.apply(
      s,
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );
    s = game.apply(s, const FoldTruco('p2'));
    expect(s.phase, TrucoPhase.handFinished);

    final next = game.apply(s, const StartNextHand());

    expect(next.handNumber, 2);
    expect(next.dealerId, 'p1');
    expect(next.openingPlayerId, 'p2');
    expect(next.turnPlayerId, 'p2');
    expect(next.hands.values.every((cards) => cards.length == 3), isTrue);
    expect(next.deck.cards.length, 33);
  });

  test('empate na primeira e segunda, terceira decide', () {
    final s = base(
      p1Cards: const [
        Card(rank: Rank.four, suit: Suit.diamonds),
        Card(rank: Rank.four, suit: Suit.hearts),
        Card(rank: Rank.three, suit: Suit.diamonds),
      ],
      p2Cards: const [
        Card(rank: Rank.four, suit: Suit.spades),
        Card(rank: Rank.four, suit: Suit.clubs),
        Card(rank: Rank.two, suit: Suit.diamonds),
      ],
    );

    var next = s;
    final game = const TrucoGame();

    next = game.apply(
      next,
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.four, suit: Suit.diamonds),
      ),
    );
    next = game.apply(
      next,
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.four, suit: Suit.spades),
      ),
    );
    next = game.apply(
      next,
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.four, suit: Suit.hearts),
      ),
    );
    next = game.apply(
      next,
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.four, suit: Suit.clubs),
      ),
    );
    next = game.apply(
      next,
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.three, suit: Suit.diamonds),
      ),
    );
    next = game.apply(
      next,
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.two, suit: Suit.diamonds),
      ),
    );

    expect(next.teamScores['t1'], 1);
    expect(next.handWinnerTeamId, 't1');
  });
}
