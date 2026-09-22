import 'dart:math';

import 'package:test/test.dart';
import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';
import 'package:trucaralho/games/truco/truco_action.dart';
import 'package:trucaralho/games/truco/truco_game.dart';
import 'package:trucaralho/games/truco/truco_state.dart';

void main() {
  const players = [
    Player(id: 'p1', name: 'P1'),
    Player(id: 'p2', name: 'P2', kind: PlayerKind.ai),
  ];
  const teams = [
    Team(id: 't1', name: 'Nós', playerIds: ['p1']),
    Team(id: 't2', name: 'Eles', playerIds: ['p2']),
  ];

  test('startGame cria uma partida nova com placar zerado e mão válida', () {
    final state = const TrucoGame(random: Random(42)).startGame(
      players: players,
      teams: teams,
      openingPlayerId: 'p1',
      dealerId: 'p2',
    );

    expect(state.handNumber, 1);
    expect(state.teamScores, {'t1': 0, 't2': 0});
    expect(state.phase, TrucoPhase.playing);
    expect(state.currentTrick, 1);
    expect(state.turnPlayerId, 'p1');
    expect(state.dealerId, 'p2');
    expect(state.openingPlayerId, 'p1');
    expect(state.hands.values.every((cards) => cards.length == 3), isTrue);
    expect(state.deck.cards.length, 33);
  });

  test('partida em 11 encerra na Mão de Onze quando a equipe vence duas vazas', () {
    const game = TrucoGame();
    var state = game.newGame(
      players: players,
      teams: teams,
      deck: Deck(const []),
      vira: const Card(rank: Rank.seven, suit: Suit.diamonds),
      hands: const {
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
      scores: {'t1': 11, 't2': 8},
    );

    expect(state.phase, TrucoPhase.waitingElevenDecision);
    state = game.apply(state, const AcceptEleven('p1'));
    expect(state.handValue, 3);

    state = game.apply(state, const PlayCard(
      playerId: 'p1',
      card: Card(rank: Rank.three, suit: Suit.diamonds),
    ));
    state = game.apply(state, const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.four, suit: Suit.diamonds),
    ));
    state = game.apply(state, const PlayCard(
      playerId: 'p1',
      card: Card(rank: Rank.two, suit: Suit.diamonds),
    ));
    state = game.apply(state, const PlayCard(
      playerId: 'p2',
      card: Card(rank: Rank.five, suit: Suit.diamonds),
    ));

    expect(state.phase, TrucoPhase.gameFinished);
    expect(state.gameWinnerTeamId, 't1');
    expect(state.teamScores, {'t1': 14, 't2': 8});
  });

  test('rotação de distribuidor e jogador inicial permanece consistente entre mãos', () {
    final game = TrucoGame(random: Random(7));
    var state = game.startGame(
      players: players,
      teams: teams,
      openingPlayerId: 'p1',
      dealerId: 'p2',
    );

    state = game.apply(
      state,
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );
    state = game.apply(state, const FoldTruco('p2'));

    final hand2 = game.apply(state, const StartNextHand());
    expect(hand2.handNumber, 2);
    expect(hand2.dealerId, 'p1');
    expect(hand2.openingPlayerId, 'p2');
    expect(hand2.turnPlayerId, 'p2');

    state = game.apply(
      hand2,
      const RequestTruco(playerId: 'p2', requestedValue: 3),
    );
    state = game.apply(state, const FoldTruco('p1'));

    final hand3 = game.apply(state, const StartNextHand());
    expect(hand3.handNumber, 3);
    expect(hand3.dealerId, 'p2');
    expect(hand3.openingPlayerId, 'p1');
    expect(hand3.turnPlayerId, 'p1');
  });

  test('partida 2x2 mantém duas equipes e rotação circular dos quatro jogadores', () {
    const fourPlayers = [
      Player(id: 'a', name: 'A'),
      Player(id: 'b', name: 'B', kind: PlayerKind.ai),
      Player(id: 'c', name: 'C', kind: PlayerKind.ai),
      Player(id: 'd', name: 'D', kind: PlayerKind.ai),
    ];
    const fourTeams = [
      Team(id: 'x', name: 'X', playerIds: ['a', 'c']),
      Team(id: 'y', name: 'Y', playerIds: ['b', 'd']),
    ];

    final state = const TrucoGame(random: Random(42)).startGame(
      players: fourPlayers,
      teams: fourTeams,
      openingPlayerId: 'a',
      dealerId: 'd',
    );

    expect(state.players.map((p) => p.id), ['a', 'b', 'c', 'd']);
    expect(state.teamScores, {'x': 0, 'y': 0});
    expect(state.hands.length, 4);
    expect(state.hands.values.every((cards) => cards.length == 3), isTrue);
    expect(state.deck.cards.length, 27);
  });

  test('não é possível iniciar próxima mão depois que a partida terminou', () {
    const game = TrucoGame();
    final state = game.startGame(
      players: players,
      teams: teams,
      openingPlayerId: 'p1',
      dealerId: 'p2',
    ).copyWith(
      phase: TrucoPhase.gameFinished,
      gameWinnerTeamId: 't1',
      teamScores: {'t1': 12, 't2': 0},
    );

    expect(
      () => game.apply(state, const StartNextHand()),
      throwsStateError,
    );
  });

}
