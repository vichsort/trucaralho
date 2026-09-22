import 'package:test/test.dart';
import 'package:trucaralho/core/game/player.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';
import 'package:trucaralho/games/truco/truco_action.dart';
import 'package:trucaralho/games/truco/truco_game.dart';
import 'package:trucaralho/games/truco/truco_state.dart';

void main(){
  final p1=const Player(id:'p1',name:'P1');
  final p2=const Player(id:'p2',name:'P2',kind:PlayerKind.ai);
  final t1=Team(id:'t1',name:'Nós',playerIds:['p1']);
  final t2=Team(id:'t2',name:'Eles',playerIds:['p2']);

  TrucoState base({
    int value=1,
    List<Card>? p1Cards,
    List<Card>? p2Cards,
  })=>const TrucoGame().newGame(
    players:[p1,p2],teams:[t1,t2],deck:Deck(const []),
    vira:const Card(rank:Rank.seven,suit:Suit.diamonds),
    hands:{
      'p1':p1Cards??const [
        Card(rank:Rank.three,suit:Suit.diamonds),
        Card(rank:Rank.two,suit:Suit.diamonds),
        Card(rank:Rank.ace,suit:Suit.diamonds),
      ],
      'p2':p2Cards??const [
        Card(rank:Rank.four,suit:Suit.diamonds),
        Card(rank:Rank.five,suit:Suit.diamonds),
        Card(rank:Rank.six,suit:Suit.diamonds),
      ],
    },
    openingPlayerId:'p1',
  ).copyWith(handValue:value);

  test('pedido mantém valor vigente e registra anterior/solicitado',(){
    final next=const TrucoGame().apply(base(),const RequestTruco(playerId:'p1',requestedValue:3));
    expect(next.handValue,1);
    expect(next.pendingRaise!.previousValue,1);
    expect(next.pendingRaise!.requestedValue,3);
    expect(next.phase,TrucoPhase.waitingTrucoResponse);
  });

  test('resposta pode aumentar de 3 para 6 e a recusa entrega 3',(){
    final game=const TrucoGame();
    final requested=game.apply(base(),const RequestTruco(playerId:'p1',requestedValue:3));
    final raised=game.apply(requested,const RaiseTruco(playerId:'p2',requestedValue:6));
    expect(raised.pendingRaise!.previousValue,3);
    expect(raised.pendingRaise!.requestedValue,6);
    final folded=game.apply(raised,const FoldTruco('p1'));
    expect(folded.teamScores['t2'],3);
  });

  test('aceite aplica o novo valor e mantém a vez de quem fez o último pedido',(){
    final pending=const TrucoRaise(
      requesterId:'p1',responderId:'p2',previousValue:3,requestedValue:6);
    final next=const TrucoGame().apply(
      base(value:3).copyWith(pendingRaise:pending),const AcceptTruco('p2'));
    expect(next.handValue,6);
    expect(next.turnPlayerId,'p1');
  });

  test('correr após pedido de 6 dá 3, não 6',(){
    final pending=const TrucoRaise(
      requesterId:'p1',responderId:'p2',previousValue:3,requestedValue:6);
    final next=const TrucoGame().apply(
      base(value:3).copyWith(pendingRaise:pending),const FoldTruco('p2'));
    expect(next.teamScores['t1'],3);
    expect(next.phase,TrucoPhase.handFinished);
  });

  test('empate na primeira vaza e vitória na segunda encerra a mão',(){
    final game=const TrucoGame();
    var s=base(
      p1Cards:const [
        Card(rank:Rank.four,suit:Suit.diamonds),
        Card(rank:Rank.three,suit:Suit.diamonds),
        Card(rank:Rank.ace,suit:Suit.diamonds),
      ],
      p2Cards:const [
        Card(rank:Rank.four,suit:Suit.spades),
        Card(rank:Rank.two,suit:Suit.diamonds),
        Card(rank:Rank.ace,suit:Suit.hearts),
      ],
    );
    s=game.apply(s,const PlayCard(
      playerId:'p1',card:Card(rank:Rank.four,suit:Suit.diamonds)));
    s=game.apply(s,const PlayCard(
      playerId:'p2',card:Card(rank:Rank.four,suit:Suit.spades)));
    expect(s.tricks[0].tied,isTrue);
    expect(s.turnPlayerId,'p1');

    s=game.apply(s,const PlayCard(
      playerId:'p1',card:Card(rank:Rank.three,suit:Suit.diamonds)));
    s=game.apply(s,const PlayCard(
      playerId:'p2',card:Card(rank:Rank.two,suit:Suit.diamonds)));
    expect(s.handWinnerTeamId,'t1');
    expect(s.teamScores['t1'],1);
  });

  test('três vazas empatadas não dão ponto',(){
    final game=const TrucoGame();
    var s=base(
      p1Cards:const [
        Card(rank:Rank.four,suit:Suit.diamonds),
        Card(rank:Rank.five,suit:Suit.diamonds),
        Card(rank:Rank.six,suit:Suit.diamonds),
      ],
      p2Cards:const [
        Card(rank:Rank.four,suit:Suit.spades),
        Card(rank:Rank.five,suit:Suit.spades),
        Card(rank:Rank.six,suit:Suit.spades),
      ],
    );
    for(final pair in [
      [const Card(rank:Rank.four,suit:Suit.diamonds),const Card(rank:Rank.four,suit:Suit.spades)],
      [const Card(rank:Rank.five,suit:Suit.diamonds),const Card(rank:Rank.five,suit:Suit.spades)],
      [const Card(rank:Rank.six,suit:Suit.diamonds),const Card(rank:Rank.six,suit:Suit.spades)],
    ]){
      s=game.apply(s,PlayCard(playerId:s.turnPlayerId,card:pair[0]));
      s=game.apply(s,PlayCard(playerId:s.turnPlayerId,card:pair[1]));
    }
    expect(s.phase,TrucoPhase.handFinished);
    expect(s.teamScores['t1'],0);
    expect(s.teamScores['t2'],0);
  });

  test('estado intermediário com Truco pendente pode ser restaurado',(){
    final state=const TrucoGame().apply(
      base(),const RequestTruco(playerId:'p1',requestedValue:3));
    final restored=TrucoState.fromJson(state.toJson());
    expect(restored.toJson(),state.toJson());
    expect(restored.pendingRaise!.requestedValue,3);
    expect(restored.pendingRaise!.previousValue,1);
  });

  test('4 jogadores são validados como duas equipes de dois',(){
    final players=[
      const Player(id:'a',name:'A'),
      const Player(id:'b',name:'B',kind:PlayerKind.ai),
      const Player(id:'c',name:'C',kind:PlayerKind.ai),
      const Player(id:'d',name:'D',kind:PlayerKind.ai),
    ];
    final teams=[
      Team(id:'t1',name:'Time 1',playerIds:['a','c']),
      Team(id:'t2',name:'Time 2',playerIds:['b','d']),
    ];
    final hands={for(final p in players)p.id:const [
      Card(rank:Rank.four,suit:Suit.diamonds),
      Card(rank:Rank.five,suit:Suit.spades),
      Card(rank:Rank.six,suit:Suit.hearts),
    ]};
    final state=const TrucoGame().newGame(
      players:players,teams:teams,deck:Deck(const []),
      vira:const Card(rank:Rank.seven,suit:Suit.diamonds),
      hands:hands,openingPlayerId:'a');
    expect(state.teams.every((t)=>t.playerIds.length==2),isTrue);
  });
}
