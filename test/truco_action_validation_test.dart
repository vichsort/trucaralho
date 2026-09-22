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
const t1 = Team(id: 't1', name: 'T1', playerIds: ['p1']);
const t2 = Team(id: 't2', name: 'T2', playerIds: ['p2']);

const p1Card1 = Card(rank: Rank.three, suit: Suit.diamonds);
const p1Card2 = Card(rank: Rank.two, suit: Suit.diamonds);
const p1Card3 = Card(rank: Rank.ace, suit: Suit.diamonds);
const p2Card1 = Card(rank: Rank.four, suit: Suit.spades);
const p2Card2 = Card(rank: Rank.five, suit: Suit.spades);
const p2Card3 = Card(rank: Rank.six, suit: Suit.spades);
const vira = Card(rank: Rank.seven, suit: Suit.hearts);

TrucoState base({
  Map<String, int>? scores,
  int handValue = 1,
  TrucoPhase? phase,
  String openingPlayerId = 'p1',
  String dealerId = 'p2',
  List<Card> p1Cards = const [p1Card1, p1Card2, p1Card3],
  List<Card> p2Cards = const [p2Card1, p2Card2, p2Card3],
}) {
  final state = const TrucoGame().newGame(
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

  return phase == null ? state : state.copyWith(phase: phase);
}

void main() {
  const game = TrucoGame();

  test('PlayCard rejeita jogador desconhecido', () {
    final state = base();
    expect(
      () => game.apply(
        state,
        const PlayCard(playerId: 'ghost', card: p1Card1),
      ),
      throwsStateError,
    );
  });

  test('PlayCard rejeita jogador fora da vez sem alterar o estado', () {
    final state = base();
    expect(
      () => game.apply(
        state,
        const PlayCard(playerId: 'p2', card: p2Card1),
      ),
      throwsStateError,
    );
    expect(state.turnPlayerId, 'p1');
    expect(state.tricks, isEmpty);
  });

  test('PlayCard rejeita ação quando a mão já terminou', () {
    final state = base(phase: TrucoPhase.handFinished);
    expect(
      () => game.apply(
        state,
        const PlayCard(playerId: 'p1', card: p1Card1),
      ),
      throwsStateError,
    );
  });

  test('RequestTruco rejeita jogador desconhecido', () {
    final state = base();
    expect(
      () => game.apply(
        state,
        const RequestTruco(playerId: 'ghost', requestedValue: 3),
      ),
      throwsStateError,
    );
  });

  test('RequestTruco rejeita salto de valor', () {
    final state = base();
    expect(
      () => game.apply(
        state,
        const RequestTruco(playerId: 'p1', requestedValue: 6),
      ),
      throwsStateError,
    );
  });

  test('RequestTruco rejeita pedido fora da vez', () {
    final state = base();
    expect(
      () => game.apply(
        state,
        const RequestTruco(playerId: 'p2', requestedValue: 3),
      ),
      throwsStateError,
    );
  });

  test('RequestTruco não pode substituir negociação pendente', () {
    final state = game.apply(
      base(),
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    expect(
      () => game.apply(
        state,
        const RequestTruco(playerId: 'p1', requestedValue: 3),
      ),
      throwsStateError,
    );
  });

  test('RequestTruco rejeita Mão de Onze e Mão de Ferro', () {
    final eleven = base(scores: const {'t1': 11, 't2': 8});
    final accepted = game.apply(eleven, const AcceptEleven('p1'));
    expect(
      () => game.apply(
        accepted,
        const RequestTruco(playerId: 'p1', requestedValue: 6),
      ),
      throwsStateError,
    );

    final blind = base(scores: const {'t1': 11, 't2': 11});
    expect(
      () => game.apply(
        blind,
        const RequestTruco(playerId: 'p1', requestedValue: 3),
      ),
      throwsStateError,
    );
  });

  test('RaiseTruco rejeita quem não é o respondente', () {
    final pending = game.apply(
      base(),
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    expect(
      () => game.apply(
        pending,
        const RaiseTruco(playerId: 'p1', requestedValue: 6),
      ),
      throwsStateError,
    );
  });

  test('RaiseTruco exige exatamente o próximo valor', () {
    final pending = game.apply(
      base(),
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    expect(
      () => game.apply(
        pending,
        const RaiseTruco(playerId: 'p2', requestedValue: 9),
      ),
      throwsStateError,
    );
  });

  test('RaiseTruco rejeita responder inexistente', () {
    final state = base().copyWith(
      phase: TrucoPhase.waitingTrucoResponse,
      pendingRaise: const TrucoRaise(
        requesterId: 'p1',
        responderId: 'ghost',
        previousValue: 3,
        requestedValue: 6,
      ),
    );

    expect(
      () => game.apply(
        state,
        const RaiseTruco(playerId: 'p2', requestedValue: 9),
      ),
      throwsStateError,
    );
  });

  test('AcceptTruco e FoldTruco exigem negociação pendente', () {
    final state = base();

    expect(
      () => game.apply(state, const AcceptTruco('p2')),
      throwsStateError,
    );
    expect(
      () => game.apply(state, const FoldTruco('p2')),
      throwsStateError,
    );
  });

  test('AcceptTruco e FoldTruco rejeitam quem não é o respondente', () {
    final pending = game.apply(
      base(),
      const RequestTruco(playerId: 'p1', requestedValue: 3),
    );

    expect(
      () => game.apply(pending, const AcceptTruco('p1')),
      throwsStateError,
    );
    expect(
      () => game.apply(pending, const FoldTruco('p1')),
      throwsStateError,
    );
  });

  test('AcceptEleven e FoldEleven exigem membro da equipe com 11', () {
    final state = base(scores: const {'t1': 11, 't2': 8});

    expect(
      () => game.apply(state, const AcceptEleven('p2')),
      throwsStateError,
    );
    expect(
      () => game.apply(state, const FoldEleven('p2')),
      throwsStateError,
    );
  });

  test('decisão de Mão de Onze não pode ser repetida após aceite', () {
    final state = base(scores: const {'t1': 11, 't2': 8});
    final accepted = game.apply(state, const AcceptEleven('p1'));

    expect(
      () => game.apply(accepted, const AcceptEleven('p1')),
      throwsStateError,
    );
    expect(
      () => game.apply(accepted, const FoldEleven('p1')),
      throwsStateError,
    );
  });

  test('StartNextHand só funciona após encerramento da mão', () {
    final state = base();
    expect(
      () => game.apply(state, const StartNextHand()),
      throwsStateError,
    );
  });

  test('StartNextHand não reabre partida encerrada', () {
    final state = base().copyWith(
      phase: TrucoPhase.gameFinished,
      gameWinnerTeamId: 't1',
      teamScores: const {'t1': 12, 't2': 0},
    );

    expect(
      () => game.apply(state, const StartNextHand()),
      throwsStateError,
    );
  });

  test('newGame rejeita placar com equipe inexistente', () {
    expect(
      () => base(scores: const {'t3': 1}),
      throwsArgumentError,
    );
  });

  test('newGame rejeita número de mão inválido', () {
    expect(
      () => const TrucoGame().newGame(
        players: [p1, p2],
        teams: [t1, t2],
        deck: Deck(const []),
        vira: vira,
        hands: const {
          'p1': [p1Card1, p1Card2, p1Card3],
          'p2': [p2Card1, p2Card2, p2Card3],
        },
        openingPlayerId: 'p1',
        dealerId: 'p2',
        handNumber: 0,
      ),
      throwsArgumentError,
    );
  });

  test('newGame rejeita mão sem três cartas por jogador', () {
    expect(
      () => const TrucoGame().newGame(
        players: [p1, p2],
        teams: [t1, t2],
        deck: Deck(const []),
        vira: vira,
        hands: {
          'p1': const [p1Card1, p1Card2],
          'p2': const [p2Card1, p2Card2, p2Card3],
        },
        openingPlayerId: 'p1',
        dealerId: 'p2',
      ),
      throwsArgumentError,
    );
  });

  test('newGame rejeita baralho com cartas duplicadas', () {
    const duplicated = Card(rank: Rank.queen, suit: Suit.clubs);

    expect(
      () => const TrucoGame().newGame(
        players: [p1, p2],
        teams: [t1, t2],
        deck: Deck(const [duplicated, duplicated]),
        vira: vira,
        hands: const {
          'p1': [p1Card1, p1Card2, p1Card3],
          'p2': [p2Card1, p2Card2, p2Card3],
        },
        openingPlayerId: 'p1',
        dealerId: 'p2',
      ),
      throwsArgumentError,
    );
  });

  test('newGame rejeita vira presente no baralho', () {
    expect(
      () => const TrucoGame().newGame(
        players: [p1, p2],
        teams: [t1, t2],
        deck: Deck(const [vira]),
        vira: vira,
        hands: const {
          'p1': [p1Card1, p1Card2, p1Card3],
          'p2': [p2Card1, p2Card2, p2Card3],
        },
        openingPlayerId: 'p1',
        dealerId: 'p2',
      ),
      throwsArgumentError,
    );
  });

  test('newGame rejeita duas equipes com o mesmo id', () {
    const duplicateTeamId = [
      Team(id: 'same', name: 'A', playerIds: ['p1']),
      Team(id: 'same', name: 'B', playerIds: ['p2']),
    ];

    expect(
      () => const TrucoGame().newGame(
        players: [p1, p2],
        teams: duplicateTeamId,
        deck: Deck(const []),
        vira: vira,
        hands: const {
          'p1': [p1Card1, p1Card2, p1Card3],
          'p2': [p2Card1, p2Card2, p2Card3],
        },
        openingPlayerId: 'p1',
        dealerId: 'p2',
      ),
      throwsArgumentError,
    );
  });

  test('newGame exige abertura imediatamente após o distribuidor', () {
    expect(
      () => const TrucoGame().newGame(
        players: [p1, p2],
        teams: [t1, t2],
        deck: Deck(const []),
        vira: vira,
        hands: const {
          'p1': [p1Card1, p1Card2, p1Card3],
          'p2': [p2Card1, p2Card2, p2Card3],
        },
        openingPlayerId: 'p1',
        dealerId: 'p1',
      ),
      throwsArgumentError,
    );
  });

  test('newGame exige alternância de equipes em partida 2x2', () {
    const fourPlayers = [
      Player(id: 'a', name: 'A'),
      Player(id: 'b', name: 'B', kind: PlayerKind.ai),
      Player(id: 'c', name: 'C', kind: PlayerKind.ai),
      Player(id: 'd', name: 'D', kind: PlayerKind.ai),
    ];
    const invalidTeams = [
      Team(id: 'x', name: 'X', playerIds: ['a', 'b']),
      Team(id: 'y', name: 'Y', playerIds: ['c', 'd']),
    ];
    const hands = {
      'a': const [
        Card(rank: Rank.four, suit: Suit.diamonds),
        Card(rank: Rank.five, suit: Suit.diamonds),
        Card(rank: Rank.six, suit: Suit.diamonds),
      ],
      'b': const [
        Card(rank: Rank.four, suit: Suit.spades),
        Card(rank: Rank.five, suit: Suit.spades),
        Card(rank: Rank.six, suit: Suit.spades),
      ],
      'c': const [
        Card(rank: Rank.four, suit: Suit.hearts),
        Card(rank: Rank.five, suit: Suit.hearts),
        Card(rank: Rank.six, suit: Suit.hearts),
      ],
      'd': const [
        Card(rank: Rank.four, suit: Suit.clubs),
        Card(rank: Rank.five, suit: Suit.clubs),
        Card(rank: Rank.six, suit: Suit.clubs),
      ],
    };

    expect(
      () => const TrucoGame().newGame(
        players: fourPlayers,
        teams: invalidTeams,
        deck: Deck(const []),
        vira: vira,
        hands: hands,
        openingPlayerId: 'a',
        dealerId: 'd',
      ),
      throwsArgumentError,
    );
  });
}
