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

  TrucoState newGame({
    required List<Player> players,
    required List<Team> teams,
    required Deck deck,
    required Card vira,
    required Map<String, List<Card>> hands,
    required String openingPlayerId,
  }) {
    _validatePlayersAndTeams(players, teams);
    if (hands.length != players.length || hands.values.any((cards) => cards.length != 3)) {
      throw ArgumentError('Cada jogador deve receber exatamente 3 cartas.');
    }

    return TrucoState(
      players: players,
      teams: teams,
      deck: deck,
      vira: vira,
      hands: hands,
      tricks: const [],
      currentTrick: 1,
      turnPlayerId: openingPlayerId,
      openingPlayerId: openingPlayerId,
      teamScores: {for (final team in teams) team.id: 0},
      handValue: 1,
      pendingRaise: null,
      phase: TrucoPhase.playing,
      handWinnerTeamId: null,
      gameWinnerTeamId: null,
    );
  }

  TrucoState startHand({
    required List<Player> players,
    required List<Team> teams,
    required Deck deck,
    required String openingPlayerId,
  }) {
    _validatePlayersAndTeams(players, teams);
    final shuffled = deck.shuffled();
    final (remainingAfterVira, drawnVira) = shuffled.draw(1);
    var remaining = remainingAfterVira;
    final hands = <String, List<Card>>{};
    final orderedPlayers = _orderedPlayers(players, openingPlayerId);
    for (final player in orderedPlayers) {
      final draw = remaining.draw(3);
      remaining = draw.$1;
      hands[player.id] = draw.$2;
    }

    return newGame(
      players: players,
      teams: teams,
      deck: remaining,
      vira: drawnVira.single,
      hands: hands,
      openingPlayerId: openingPlayerId,
    );
  }

  @override
  TrucoState apply(TrucoState state, TrucoAction action) => switch (action) {
        PlayCard() => _playCard(state, action),
        RequestTruco() => _requestTruco(state, action),
        AcceptTruco() => _acceptTruco(state, action),
        FoldTruco() => _foldTruco(state, action),
      };

  TrucoState _requestTruco(TrucoState state, RequestTruco action) {
    _requirePlaying(state);
    _requireTurn(state, action.playerId);
    if (state.handValue >= 12) throw StateError('A mão já vale 12.');
    final expected = TrucoRules.nextValue(state.handValue);
    if (action.requestedValue != expected) throw StateError('Aumento inválido.');
    final responder = _nextPlayer(state, action.playerId);
    return state.copyWith(
      pendingRaise: TrucoRaise(
        requesterId: action.playerId,
        responderId: responder,
        previousValue: state.handValue,
        requestedValue: action.requestedValue,
      ),
      phase: TrucoPhase.waitingTrucoResponse,
    );
  }

  TrucoState _acceptTruco(TrucoState state, AcceptTruco action) {
    final raise = state.pendingRaise;
    if (state.phase != TrucoPhase.waitingTrucoResponse || raise == null) {
      throw StateError('Não há Truco aguardando resposta.');
    }
    if (action.playerId != raise.responderId) throw StateError('Jogador não pode responder.');
    return state.copyWith(
      handValue: raise.requestedValue,
      clearPendingRaise: true,
      phase: TrucoPhase.playing,
      turnPlayerId: raise.requesterId,
    );
  }

  TrucoState _foldTruco(TrucoState state, FoldTruco action) {
    final raise = state.pendingRaise;
    if (state.phase != TrucoPhase.waitingTrucoResponse || raise == null) {
      throw StateError('Não há Truco aguardando resposta.');
    }
    if (action.playerId != raise.responderId) throw StateError('Jogador não pode correr.');
    final winnerTeam = _teamOf(state, raise.requesterId);
    final scores = {...state.teamScores};
    scores[winnerTeam.id] = scores[winnerTeam.id]! + raise.previousValue;
    final finished = scores[winnerTeam.id]! >= 12;
    return state.copyWith(
      teamScores: scores,
      clearPendingRaise: true,
      phase: finished ? TrucoPhase.gameFinished : TrucoPhase.handFinished,
      handWinnerTeamId: winnerTeam.id,
      gameWinnerTeamId: finished ? winnerTeam.id : null,
    );
  }

  TrucoState _playCard(TrucoState state, PlayCard action) {
    _requirePlaying(state);
    _requireTurn(state, action.playerId);
    final hand = state.hands[action.playerId];
    if (hand == null || !hand.contains(action.card)) throw StateError('Carta não pertence à mão.');

    final hands = {...state.hands, action.playerId: [...hand]..remove(action.card)};
    final current = state.tricks.isEmpty || state.tricks.last.cards.length == 2
        ? Trick(number: state.currentTrick, cards: const [])
        : state.tricks.last;
    final cards = [...current.cards, PlayedCard(playerId: action.playerId, card: action.card)];
    final tricks = [...state.tricks];
    if (cards.length == 1) {
      if (tricks.isEmpty || tricks.last.cards.length == 2) {
        tricks.add(Trick(number: state.currentTrick, cards: cards));
      } else {
        tricks[tricks.length - 1] = current.copyWith(cards: cards);
      }
      return state.copyWith(
        hands: hands,
        tricks: tricks,
        turnPlayerId: _nextPlayer(state, action.playerId),
      );
    }

    final first = cards[0];
    final second = cards[1];
    final comparison = TrucoRules.compare(first.card, second.card, state.vira);
    final winner = comparison == 0 ? state.openingPlayerId : (comparison > 0 ? first.playerId : second.playerId);
    tricks[tricks.length - 1] = current.copyWith(cards: cards, winnerId: winner);

    final scores = _trickWins(state, tricks);
    final winnerTeam = _resolveHandWinner(state, tricks);
    if (winnerTeam != null) {
      final updatedScores = {...state.teamScores};
      updatedScores[winnerTeam] = updatedScores[winnerTeam]! + state.handValue;
      final gameFinished = updatedScores[winnerTeam]! >= 12;
      return state.copyWith(
        hands: hands,
        tricks: tricks,
        teamScores: updatedScores,
        phase: gameFinished ? TrucoPhase.gameFinished : TrucoPhase.handFinished,
        handWinnerTeamId: winnerTeam,
        gameWinnerTeamId: gameFinished ? winnerTeam : null,
      );
    }

    final next = winner;
    return state.copyWith(
      hands: hands,
      tricks: tricks,
      currentTrick: state.currentTrick + 1,
      openingPlayerId: next,
      turnPlayerId: next,
      phase: TrucoPhase.playing,
    );
  }

  Map<String, int> _trickWins(TrucoState state, List<Trick> tricks) {
    final result = {for (final team in state.teams) team.id: 0};
    for (final trick in tricks.where((t) => t.winnerId != null)) {
      result[_teamOf(state, trick.winnerId!).id] =
          result[_teamOf(state, trick.winnerId!).id]! + 1;
    }
    return result;
  }

  String? _resolveHandWinner(TrucoState state, List<Trick> tricks) {
    final wins = _trickWins(state, tricks);
    for (final team in state.teams) {
      if (wins[team.id]! >= 2) return team.id;
    }
    if (tricks.length == 3) {
      final winners = tricks.where((t) => t.winnerId != null).map((t) => t.winnerId!).toList();
      if (winners.isEmpty) return null;
      return _teamOf(state, winners.first).id;
    }
    return null;
  }

  Map<String, int> _dummy() => {};

  String _nextPlayer(TrucoState state, String id) {
    final index = state.players.indexWhere((p) => p.id == id);
    return state.players[(index + 1) % state.players.length].id;
  }

  List<Player> _orderedPlayers(List<Player> players, String opening) {
    final index = players.indexWhere((p) => p.id == opening);
    if (index < 0) throw ArgumentError('Jogador inicial inexistente.');
    return [...players.sublist(index), ...players.sublist(0, index)];
  }

  Team _teamOf(TrucoState state, String playerId) =>
      state.teams.firstWhere((team) => team.playerIds.contains(playerId));

  void _requireTurn(TrucoState state, String id) {
    if (state.turnPlayerId != id) throw StateError('Não é a vez deste jogador.');
  }

  void _requirePlaying(TrucoState state) {
    if (state.phase != TrucoPhase.playing) throw StateError('A partida não está aceitando jogadas.');
  }

  void _validatePlayersAndTeams(List<Player> players, List<Team> teams) {
    if (players.length != 2 && players.length != 4) {
      throw ArgumentError('Truco suporta 2 ou 4 jogadores.');
    }
    final ids = players.map((p) => p.id).toSet();
    if (ids.length != players.length ||
        teams.length != 2 ||
        teams.any((team) => team.playerIds.any((id) => !ids.contains(id))) ||
        teams.expand((t) => t.playerIds).toSet().length != players.length) {
      throw ArgumentError('Times devem cobrir todos os jogadores exatamente uma vez.');
    }
    if (players.length == 2 && teams.any((t) => t.playerIds.length != 1)) {
      throw ArgumentError('Partida de 2 jogadores exige um jogador por time.');
    }
    if (players.length == 4 && teams.any((t) => t.playerIds.length != 2)) {
      throw ArgumentError('Partida de 4 jogadores exige dois jogadores por time.');
    }
  }
}
