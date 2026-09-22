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
import 'package:trucaralho/games/truco/truco_rules.dart';
import 'package:trucaralho/games/truco/truco_state.dart';

void main() {
  const p1 = Player(id: 'p1', name: 'P1');
  const p2 = Player(id: 'p2', name: 'P2', kind: PlayerKind.ai);
  const t1 = Team(id: 't1', name: 'T1', playerIds: ['p1']);
  const t2 = Team(id: 't2', name: 'T2', playerIds: ['p2']);

  TrucoState stateWith({
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
      ).copyWith(
        hands: {
          'p1': p1Cards ?? const [
            Card(rank: Rank.three, suit: Suit.diamonds),
            Card(rank: Rank.two, suit: Suit.diamonds),
            Card(rank: Rank.ace, suit: Suit.diamonds),
          ],
          'p2': p2Cards ?? const [
            Card(rank: Rank.four, suit: Suit.diamonds),
            Card(rank: Rank.five, suit: Suit.diamonds),
            Card(rank: Rank.six, suit: Suit.diamonds),
          ],
        },
      );

  test('hierarquia não-manilha e manilhas seguem Truco Paulista', () {
    const vira = Card(rank: Rank.seven, suit: Suit.diamonds);

    expect(
      TrucoRules.compare(
        const Card(rank: Rank.three, suit: Suit.diamonds),
        const Card(rank: Rank.two, suit: Suit.diamonds),
        vira,
      ),
      greaterThan(0),
    );

    expect(
      TrucoRules.compare(
        const Card(rank: Rank.queen, suit: Suit.clubs),
        const Card(rank: Rank.three, suit: Suit.diamonds),
        vira,
      ),
      greaterThan(0),
    );

    expect(
      TrucoRules.compare(
        const Card(rank: Rank.queen, suit: Suit.clubs),
        const Card(rank: Rank.queen, suit: Suit.hearts),
        vira,
      ),
      greaterThan(0),
    );
  });

  test('vira 3 faz 4 ser manilha, com 4 cíclico', () {
    const vira = Card(rank: Rank.three, suit: Suit.diamonds);
    expect(TrucoRules.manilhaRank(vira), Rank.four);
    expect(
      TrucoRules.isManilha(
        const Card(rank: Rank.four, suit: Suit.clubs),
        vira,
      ),
      isTrue,
    );
  });

  test('empate: primeira vaza empatada e segunda decide', () {
    var s = stateWith(
      p1Cards: const [
        Card(rank: Rank.four, suit: Suit.diamonds),
        Card(rank: Rank.three, suit: Suit.diamonds),
        Card(rank: Rank.ace, suit: Suit.diamonds),
      ],
      p2Cards: const [
        Card(rank: Rank.four, suit: Suit.spades),
        Card(rank: Rank.two, suit: Suit.diamonds),
        Card(rank: Rank.ace, suit: Suit.hearts),
      ],
    );
    const game = TrucoGame();

    s = game.apply(s, const PlayCard(
      playerId: 'p1',
      card: Card(rank: Rank.four, suit: Suit.diamonds),
    ));
    s = game.apply(s, const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.four, suit: Suit.spades),
    ));
    s = game.apply(s, const PlayCard(
      playerId: 'p1',
      card: Card(rank: Rank.three, suit: Suit.diamonds),
    ));
    s = game.apply(s, const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.two, suit: Suit.diamonds),
    ));

    expect(s.teamScores['t1'], 1);
  });

  test('empate na segunda vaza favorece vencedor da primeira', () {
    var s = stateWith(
      p1Cards: const [
        Card(rank: Rank.three, suit: Suit.diamonds),
        Card(rank: Rank.four, suit: Suit.diamonds),
        Card(rank: Rank.ace, suit: Suit.diamonds),
      ],
      p2Cards: const [
        Card(rank: Rank.two, suit: Suit.diamonds),
        Card(rank: Rank.four, suit: Suit.spades),
        Card(rank: Rank.king, suit: Suit.diamonds),
      ],
    );
    const game = TrucoGame();

    s = game.apply(s, const PlayCard(
      playerId: 'p1',
      card: Card(rank: Rank.three, suit: Suit.diamonds),
    ));
    s = game.apply(s, const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.two, suit: Suit.diamonds),
    ));
    s = game.apply(s, const PlayCard(
      playerId: 'p1',
      card: Card(rank: Rank.four, suit: Suit.diamonds),
    ));
    s = game.apply(s, const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.four, suit: Suit.spades),
    ));

    expect(s.teamScores['t1'], 1);
  });

  test('primeira e segunda empatadas: terceira decide', () {
    var s = stateWith(
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
    const game = TrucoGame();

    for (final play in [
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.four, suit: Suit.spades),
      ),
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.four, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.four, suit: Suit.hearts),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.four, suit: Suit.clubs),
      ),
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.three, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.two, suit: Suit.diamonds),
      ),
    ]) {
      s = game.apply(s, play);
    }

    expect(s.teamScores['t1'], 1);
  });

  test('primeira vencida, segunda empatada: primeira equipe vence', () {
    var s = stateWith(
      p1Cards: const [
        Card(rank: Rank.three, suit: Suit.diamonds),
        Card(rank: Rank.four, suit: Suit.diamonds),
        Card(rank: Rank.ace, suit: Suit.diamonds),
      ],
      p2Cards: const [
        Card(rank: Rank.two, suit: Suit.diamonds),
        Card(rank: Rank.four, suit: Suit.spades),
        Card(rank: Rank.king, suit: Suit.diamonds),
      ],
    );
    const game = TrucoGame();

    for (final play in [
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.three, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.two, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.four, suit: Suit.spades),
      ),
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.four, suit: Suit.diamonds),
      ),
    ]) {
      s = game.apply(s, play);
    }

    expect(s.teamScores['t1'], 1);
  });

  test('primeira e segunda vencidas por equipes diferentes: terceira decide', () {
    var s = stateWith(
      p1Cards: const [
        Card(rank: Rank.three, suit: Suit.diamonds),
        Card(rank: Rank.four, suit: Suit.diamonds),
        Card(rank: Rank.ace, suit: Suit.diamonds),
      ],
      p2Cards: const [
        Card(rank: Rank.two, suit: Suit.diamonds),
        Card(rank: Rank.three, suit: Suit.spades),
        Card(rank: Rank.king, suit: Suit.diamonds),
      ],
    );
    const game = TrucoGame();

    for (final play in [
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.three, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.two, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.four, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.three, suit: Suit.spades),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.king, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.ace, suit: Suit.diamonds),
      ),
    ]) {
      s = game.apply(s, play);
    }

    expect(s.teamScores['t1'], 1);
  });

  test('primeira vence, segunda perde e terceira empata: primeira equipe vence', () {
    var s = stateWith(
      p1Cards: const [
        Card(rank: Rank.three, suit: Suit.diamonds),
        Card(rank: Rank.two, suit: Suit.diamonds),
        Card(rank: Rank.four, suit: Suit.diamonds),
      ],
      p2Cards: const [
        Card(rank: Rank.two, suit: Suit.spades),
        Card(rank: Rank.three, suit: Suit.spades),
        Card(rank: Rank.four, suit: Suit.spades),
      ],
    );
    const game = TrucoGame();

    for (final play in [
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.three, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.two, suit: Suit.spades),
      ),
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.two, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.three, suit: Suit.spades),
      ),
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.four, suit: Suit.diamonds),
      ),
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.four, suit: Suit.spades),
      ),
    ]) {
      s = game.apply(s, play);
    }

    expect(s.teamScores['t1'], 1);
  });

  test('três empates não pontuam', () {
    var s = stateWith(
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
    const game = TrucoGame();

    for (final pair in [
      [
        const Card(rank: Rank.four, suit: Suit.diamonds),
        const Card(rank: Rank.four, suit: Suit.spades),
      ],
      [
        const Card(rank: Rank.five, suit: Suit.diamonds),
        const Card(rank: Rank.five, suit: Suit.spades),
      ],
      [
        const Card(rank: Rank.six, suit: Suit.diamonds),
        const Card(rank: Rank.six, suit: Suit.spades),
      ],
    ]) {
      s = game.apply(s, PlayCard(playerId: s.turnPlayerId, card: pair[0]));
      s = game.apply(s, PlayCard(playerId: s.turnPlayerId, card: pair[1]));
    }

    expect(s.phase, TrucoPhase.handFinished);
    expect(s.teamScores['t1'], 0);
    expect(s.teamScores['t2'], 0);
  });

  test('IA básica responde a Truco com ação válida do domínio', () {
    final s = stateWith(
      p1Cards: const [
        Card(rank: Rank.three, suit: Suit.diamonds),
        Card(rank: Rank.two, suit: Suit.diamonds),
        Card(rank: Rank.ace, suit: Suit.diamonds),
      ],
      p2Cards: const [
        Card(rank: Rank.queen, suit: Suit.clubs),
        Card(rank: Rank.queen, suit: Suit.hearts),
        Card(rank: Rank.six, suit: Suit.diamonds),
      ],
    );
    final requested = const TrucoGame().apply(
      s,
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    final action = BasicTrucoAI(random: Random(1)).chooseAction(
      requested,
      p2,
    );

    expect(action, isA<TrucoAction>());
    expect(
      action is AcceptTruco ||
          action is RaiseTruco ||
          action is FoldTruco,
      isTrue,
    );
  });

  test('estado ativo não aceita placar terminal', () {
    expect(
      () => const TrucoGame().newGame(
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
        scores: {'t1': 12, 't2': 0},
      ),
      throwsArgumentError,
    );
  });
}
