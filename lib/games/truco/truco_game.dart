import 'dart:math';
import '../../core/game/game.dart';
import '../../core/game/player.dart';
import 'card/deck.dart';
import 'card/card.dart';
import 'trick.dart';
import 'truco_action.dart';
import 'truco_rules.dart';
import 'truco_state.dart';

final class TrucoGame implements Game<TrucoState, TrucoAction> {
  const TrucoGame();

  TrucoState startHand({
    required List<Player> players,
    required List<Team> teams,
    required String openingPlayerId,
    Random? random,
  }) {
    _validatePlayersAndTeams(players, teams);
    var remaining=Deck.truco().shuffled(random??Random());
    final ordered=_orderedPlayers(players,openingPlayerId);
    final hands=<String,List<Card>>{};
    for(final player in ordered){
      final draw=remaining.draw(3);
      remaining=draw.remaining;
      hands[player.id]=draw.drawn;
    }
    final viraDraw=remaining.draw(1);
    return newGame(
      players:players,teams:teams,deck:viraDraw.remaining,
      vira:viraDraw.drawn.single,hands:hands,openingPlayerId:openingPlayerId,
    );
  }

  TrucoState newGame({
    required List<Player> players,required List<Team> teams,required Deck deck,
    required Card vira,required Map<String,List<Card>> hands,
    required String openingPlayerId,Map<String,int>? scores,
  }){
    _validatePlayersAndTeams(players,teams);
    if(!players.any((p)=>p.id==openingPlayerId))throw ArgumentError('Jogador inicial inexistente.');
    if(hands.length!=players.length||hands.values.any((cards)=>cards.length!=3)){
      throw ArgumentError('Cada jogador deve ter 3 cartas.');
    }
    return TrucoState(
      players:players,teams:teams,deck:deck,vira:vira,hands:hands,tricks:const[],
      currentTrick:1,turnPlayerId:openingPlayerId,openingPlayerId:openingPlayerId,
      teamScores:scores??{for(final t in teams)t.id:0},handValue:1,
      pendingRaise:null,phase:TrucoPhase.playing,handWinnerTeamId:null,gameWinnerTeamId:null,
    );
  }

  @override
  TrucoState apply(TrucoState state,TrucoAction action)=>switch(action){
    PlayCard()=>_play(state,action),
    RequestTruco()=>_request(state,action),
    AcceptTruco()=>_accept(state,action),
    FoldTruco()=>_fold(state,action),
  };

  TrucoState _request(TrucoState s,RequestTruco a){
    _playing(s);_turn(s,a.playerId);
    final expected=TrucoRules.nextValue(s.handValue);
    if(a.requestedValue!=expected)throw StateError('Aumento inválido.');
    return s.copyWith(
      pendingRaise:TrucoRaise(
        requesterId:a.playerId,responderId:_nextPlayer(s,a.playerId),
        previousValue:s.handValue,requestedValue:a.requestedValue,
      ),
      phase:TrucoPhase.waitingTrucoResponse,
    );
  }

  TrucoState _accept(TrucoState s,AcceptTruco a){
    final r=s.pendingRaise;
    if(s.phase!=TrucoPhase.waitingTrucoResponse||r==null)throw StateError('Não há pedido pendente.');
    if(a.playerId!=r.responderId)throw StateError('Resposta inválida.');
    return s.copyWith(
      handValue:r.requestedValue,clearPendingRaise:true,
      phase:TrucoPhase.playing,turnPlayerId:r.requesterId,
    );
  }

  TrucoState _fold(TrucoState s,FoldTruco a){
    final r=s.pendingRaise;
    if(s.phase!=TrucoPhase.waitingTrucoResponse||r==null)throw StateError('Não há pedido pendente.');
    if(a.playerId!=r.responderId)throw StateError('Resposta inválida.');
    return _finishHand(s,_teamOf(s,r.requesterId),r.previousValue);
  }

  TrucoState _play(TrucoState s,PlayCard a){
    _playing(s);_turn(s,a.playerId);
    final hand=s.hands[a.playerId];
    if(hand==null||!hand.contains(a.card))throw StateError('Carta não pertence à mão.');

    final hands={...s.hands,a.playerId:[...hand]..remove(a.card)};
    final current=s.tricks.isEmpty||s.tricks.last.cards.length==s.players.length
      ?Trick(number:s.currentTrick,starterId:a.playerId,cards:const[])
      :s.tricks.last;
    final cards=[...current.cards,PlayedCard(playerId:a.playerId,card:a.card)];
    final completed=cards.length==s.players.length;
    final tie=completed&&_isTie(s,cards);
    final updated=Trick(
      number:current.number,starterId:current.starterId,cards:cards,
      winnerId:completed&&!tie?_trickWinner(s,cards):null,tied:tie,
    );
    final tricks=[...s.tricks];
    if(tricks.isEmpty||tricks.last.cards.length==s.players.length)tricks.add(updated);
    else tricks[tricks.length-1]=updated;

    if(!completed)return s.copyWith(hands:hands,tricks:tricks,turnPlayerId:_nextPlayer(s,a.playerId));

    final handWinner=_resolveHandWinner(s,tricks);
    if(handWinner!=null){
      return _finishHand(s.copyWith(hands:hands,tricks:tricks),_teamOf(s,handWinner),s.handValue);
    }
    if(tricks.length==3){
      return s.copyWith(hands:hands,tricks:tricks,phase:TrucoPhase.handFinished,handWinnerTeamId:null);
    }

    final next=updated.winnerId??updated.starterId;
    return s.copyWith(
      hands:hands,tricks:tricks,currentTrick:s.currentTrick+1,
      openingPlayerId:next,turnPlayerId:next,
    );
  }

  bool _isTie(TrucoState s,List<PlayedCard> cards){
    final first=cards.first.card;
    return cards.skip(1).every((p)=>TrucoRules.compare(first,p.card,s.vira)==0);
  }

  String _trickWinner(TrucoState s,List<PlayedCard> cards){
    var best=cards.first;
    for(final play in cards.skip(1)){
      if(TrucoRules.compare(best.card,play.card,s.vira)<0)best=play;
    }
    return best.playerId;
  }

  String? _resolveHandWinner(TrucoState s,List<Trick> tricks){
    final first=tricks[0].winnerId;
    if(tricks.length>=2){
      final second=tricks[1].winnerId;
      if(first!=null&&second!=null){
        if(_teamOf(s,first).id==_teamOf(s,second).id)return first;
        if(tricks.length==3){
          final third=tricks[2].winnerId;
          return third??first;
        }
        return null;
      }
      if(first==null&&second!=null)return second;
      if(first!=null&&second==null)return first;
    }
    if(tricks.length==3){
      final third=tricks[2].winnerId;
      return third;
    }
    return null;
  }

  TrucoState _finishHand(TrucoState s,Team winner,int points){
    final scores={...s.teamScores};
    scores[winner.id]=scores[winner.id]!+points;
    final ended=scores[winner.id]!>=12;
    return s.copyWith(
      teamScores:scores,phase:ended?TrucoPhase.gameFinished:TrucoPhase.handFinished,
      handWinnerTeamId:winner.id,gameWinnerTeamId:ended?winner.id:null,
      clearPendingRaise:true,
    );
  }

  Team _teamOf(TrucoState s,String playerId)=>s.teams.firstWhere((t)=>t.playerIds.contains(playerId));
  String _nextPlayer(TrucoState s,String id){
    final i=s.players.indexWhere((p)=>p.id==id);
    if(i<0)throw StateError('Jogador inexistente.');
    return s.players[(i+1)%s.players.length].id;
  }
  List<Player> _orderedPlayers(List<Player> p,String first){
    final i=p.indexWhere((x)=>x.id==first);
    if(i<0)throw ArgumentError('Jogador inicial inexistente.');
    return [...p.sublist(i),...p.sublist(0,i)];
  }
  void _turn(TrucoState s,String id){if(s.turnPlayerId!=id)throw StateError('Não é a vez deste jogador.');}
  void _playing(TrucoState s){if(s.phase!=TrucoPhase.playing)throw StateError('Partida não aceita jogadas.');}
  void _validatePlayersAndTeams(List<Player> p,List<Team> t){
    if(p.length!=2&&p.length!=4)throw ArgumentError('Truco suporta 2 ou 4 jogadores.');
    final ids=p.map((x)=>x.id).toSet();
    final covered=t.expand((x)=>x.playerIds).toList();
    if(ids.length!=p.length||t.length!=2||covered.length!=p.length||covered.toSet().length!=p.length||covered.any((x)=>!ids.contains(x))){
      throw ArgumentError('Times devem cobrir todos os jogadores exatamente uma vez.');
    }
    final expected=p.length==2?1:2;
    if(t.any((x)=>x.playerIds.length!=expected))throw ArgumentError('Composição de times inválida.');
  }
}
