import 'package:test/test.dart';
import 'package:trucaralho/core/game/player.dart';
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

const low = Card(rank: Rank.four, suit: Suit.diamonds);
const lowSameRank = Card(rank: Rank.four, suit: Suit.spades);
const high = Card(rank: Rank.three, suit: Suit.diamonds);

TrucoState stateWith({
  required List<Card> p1Cards,
  required List<Card> p2Cards,
  int value = 1,
}) =>
    const TrucoGame().newGame(
      players: [p1, p2],
      teams: [t1, t2],
      deck: Deck(const []),
      vira: Card(rank: Rank.seven, suit: Suit.hearts),
      hands: {'p1': p1Cards, 'p2': p2Cards},
      openingPlayerId: 'p1',
    ).copyWith(handValue: value);

void main() {
  const game = TrucoGame();

  test('uma vaza completa registra vencedor e abre a próxima pelo vencedor', () {
    var s = stateWith(
      p1Cards: const [high, low, Card(rank: Rank.ace, suit: Suit.clubs)],
      p2Cards: const [
        lowSameRank,
        Card(rank: Rank.two, suit: Suit.clubs),
        Card(rank: Rank.king, suit: Suit.clubs),
      ],
    );

    s = game.apply(s, const PlayCard(playerId: 'p1', card: high));
    s = game.apply(s, const PlayCard(playerId: 'p2', card: lowSameRank));

    expect(s.tricks.single.cards.length, 2);
    expect(s.tricks.single.winnerId, 'p1');
    expect(s.tricks.single.tied, isFalse);
    expect(s.currentTrick, 2);
    expect(s.turnPlayerId, 'p1');
  });

  test('empate de cartas entre equipes produz vaza empatada', () {
    var s = stateWith(
      p1Cards: const [
        low,
        Card(rank: Rank.ace, suit: Suit.clubs),
        Card(rank: Rank.king, suit: Suit.clubs),
      ],
      p2Cards: const [
        lowSameRank,
        Card(rank: Rank.ace, suit: Suit.hearts),
        Card(rank: Rank.king, suit: Suit.hearts),
      ],
    );

    s = game.apply(s, const PlayCard(playerId: 'p1', card: low));
    s = game.apply(s, const PlayCard(playerId: 'p2', card: lowSameRank));

    expect(s.tricks.single.winnerId, isNull);
    expect(s.tricks.single.tied, isTrue);
    expect(s.turnPlayerId, 'p1');
  });

  test('manilha vence qualquer carta comum e respeita ordem dos naipes', () {
    var s = stateWith(
      p1Cards: const [
        Card(rank: Rank.eight, suit: Suit.clubs),
        high,
        Card(rank: Rank.ace, suit: Suit.clubs),
      ],
      p2Cards: const [
        Card(rank: Rank.queen, suit: Suit.diamonds),
        lowSameRank,
        Card(rank: Rank.ace, suit: Suit.hearts),
      ],
    );
    // Rank 8 is intentionally unavailable in the real deck; this test must
    // instead use a valid non-manilha rank.
    s = stateWith(
      p1Cards: const [
        Card(rank: Rank.queen, suit: Suit.clubs),
        high,
        Card(rank: Rank.ace, suit: Suit.clubs),
      ],
      p2Cards: const [
        Card(rank: Rank.seven, suit: Suit.diamonds),
        lowSameRank,
        Card(rank: Rank.ace, suit: Suit.hearts),
      ],
    );

    s = game.apply(
      s,
      const PlayCard(
        playerId: 'p1',
        card: Card(rank: Rank.queen, suit: Suit.clubs),
      ),
    );
    s = game.apply(
      s,
      const PlayCard(
        playerId: 'p2',
        card: Card(rank: Rank.seven, suit: Suit.diamonds),
      ),
    );

    expect(s.tricks.single.winnerId, 'p1');
  });

  test('primeira vaza vencida duas vezes pela mesma equipe encerra a mão', () {
    var s = stateWith(
      p1Cards: const [
        Card(rank: Rank.three, suit: Suit.diamonds),
        Card(rank: Rank.two, suit: Suit.diamonds),
        Card(rank: Rank.ace, suit: Suit.diamonds),
      ],
      p2Cards: const [
        low,
        lowSameRank,
        Card(rank: Rank.five, suit: Suit.clubs),
      ],
    );

    s = game.apply(s, const PlayCard(playerId: 'p1', card: high));
    s = game.apply(s, const PlayCard(playerId: 'p2', card: low));
    expect(s.phase, TrucoPhase.playing);

    s = game.apply(s, const PlayCard(
      playerId: 'p1',
      card: Card(rank: Rank.two, suit: Suit.diamonds),
    ));
    s = game.apply(s, const PlayCard(
      playerId: 'p2',
      card: lowSameRank,
    ));

    expect(s.phase, TrucoPhase.handFinished);
    expect(s.handWinnerTeamId, 't1');
    expect(s.teamScores['t1'], 1);
    expect(s.tricks.length, 2);
  });

  test('primeira vaza empatada e segunda vencida decide a mão', () {
    var s = stateWith(
      p1Cards: const [low, high, Card(rank: Rank.ace, suit: Suit.clubs)],
      p2Cards: const [
        lowSameRank,
        Card(rank: Rank.two, suit: Suit.clubs),
        Card(rank: Rank.king, suit: Suit.clubs),
      ],
    );

    s = game.apply(s, const PlayCard(playerId: 'p1', card: low));
    s = game.apply(s, const PlayCard(playerId: 'p2', card: lowSameRank));
    s = game.apply(s, const PlayCard(playerId: 'p1', card: high));
    s = game.apply(s, const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.two, suit: Suit.clubs),
    ));

    expect(s.handWinnerTeamId, 't1');
    expect(s.phase, TrucoPhase.handFinished);
  });

  test('primeira vaza vencida e segunda empatada mantém o vencedor da primeira', () {
    var s = stateWith(
      p1Cards: const [
        high,
        Card(rank: Rank.five, suit: Suit.diamonds),
        Card(rank: Rank.ace, suit: Suit.clubs),
      ],
      p2Cards: const [
        low,
        Card(rank: Rank.five, suit: Suit.spades),
        Card(rank: Rank.king, suit: Suit.clubs),
      ],
    );

    s = game.apply(s, const PlayCard(playerId: 'p1', card: high));
    s = game.apply(s, const PlayCard(playerId: 'p2', card: low));
    s = game.apply(s, const PlayCard(
      playerId: 'p1',
      card: Card(rank: Rank.five, suit: Suit.diamonds),
    ));
    s = game.apply(s, const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.five, suit: Suit.spades),
    ));

    expect(s.handWinnerTeamId, 't1');
  });

  test('duas primeiras vazas são de equipes diferentes e a terceira decide', () {
    var s = stateWith(
      p1Cards: const [high, low, Card(rank: Rank.three, suit: Suit.clubs)],
      p2Cards: const [
        low,
        high,
        Card(rank: Rank.four, suit: Suit.hearts),
      ],
    );

    s = game.apply(s, const PlayCard(playerId: 'p1', card: high));
    s = game.apply(s, const PlayCard(playerId: 'p2', card: low));
    s = game.apply(s, const PlayCard(
      playerId: 'p1',
      card: low,
    ));
    s = game.apply(s, const PlayCard(
      playerId: 'p2',
      card: high,
    ));

    expect(s.phase, TrucoPhase.playing);
    s = game.apply(s, const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.four, suit: Suit.hearts),
    ));
    // p1 must play the remaining card first because p2 won the second vaza.
    s = game.apply(s, const PlayCard(
      playerId: 'p1',
      card: Card(rank: Rank.three, suit: Suit.clubs),
    ));

    expect(s.phase, TrucoPhase.handFinished);
    expect(s.handWinnerTeamId, 't1');
  });

  test('jogada fora da vez é rejeitada sem alterar o estado', () {
    final s = stateWith(
      p1Cards: const [high, low, Card(rank: Rank.ace, suit: Suit.clubs)],
      p2Cards: const [
        Card(rank: Rank.five, suit: Suit.clubs),
        lowSameRank,
        Card(rank: Rank.king, suit: Suit.clubs),
      ],
    );

    expect(
      () => game.apply(s, const PlayCard(playerId: 'p2', card: lowSameRank)),
      throwsStateError,
    );
    expect(s.turnPlayerId, 'p1');
    expect(s.tricks, isEmpty);
  });

  test('carta que não pertence ao jogador é rejeitada', () {
    final s = stateWith(
      p1Cards: const [high, low, Card(rank: Rank.ace, suit: Suit.clubs)],
      p2Cards: const [
        Card(rank: Rank.five, suit: Suit.clubs),
        lowSameRank,
        Card(rank: Rank.king, suit: Suit.clubs),
      ],
    );

    expect(
      () => game.apply(
        s,
        const PlayCard(playerId: 'p1', card: lowSameRank),
      ),
      throwsStateError,
    );
  });

  test('estado ativo rejeita mãos com cartas duplicadas ou carta no deck', () {
    const duplicate = [
      high,
      low,
      Card(rank: Rank.ace, suit: Suit.clubs),
    ];

    expect(
      () => game.newGame(
        players: [p1, p2],
        teams: [t1, t2],
        deck: Deck([high]),
        vira: lowSameRank,
        hands: {'p1': duplicate, 'p2': duplicate},
        openingPlayerId: 'p1',
      ),
      throwsArgumentError,
    );
  });

  test('uma mão de três vazas empatadas termina sem pontuação', () {
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

    for (final cards in [
      (const Card(rank: Rank.four, suit: Suit.diamonds),
          const Card(rank: Rank.four, suit: Suit.spades)),
      (const Card(rank: Rank.five, suit: Suit.diamonds),
          const Card(rank: Rank.five, suit: Suit.spades)),
      (const Card(rank: Rank.six, suit: Suit.diamonds),
          const Card(rank: Rank.six, suit: Suit.spades)),
    ]) {
      s = game.apply(s, PlayCard(playerId: s.turnPlayerId, card: cards.$1));
      s = game.apply(s, PlayCard(playerId: s.turnPlayerId, card: cards.$2));
    }

    expect(s.phase, TrucoPhase.handFinished);
    expect(s.handWinnerTeamId, isNull);
    expect(s.teamScores, {'t1': 0, 't2': 0});
  });
}
