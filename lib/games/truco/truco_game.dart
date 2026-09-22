import 'dart:math';

import '../../core/game/game.dart';
import '../../core/game/player.dart';
import 'card/card.dart';
import 'card/deck.dart';
import 'trick.dart';
import 'truco_action.dart';
import 'truco_rules.dart';
import 'truco_state.dart';

final class TrucoGame implements Game<TrucoState, TrucoAction> {
  final Random? random;

  const TrucoGame({this.random});

  /// Starts a new match from zero points and deals its first hand.
  TrucoState startGame({
    required List<Player> players,
    required List<Team> teams,
    required String openingPlayerId,
    Random? random,
    String? dealerId,
  }) =>
      startHand(
        players: players,
        teams: teams,
        openingPlayerId: openingPlayerId,
        random: random,
        dealerId: dealerId,
        scores: const {},
      );

  TrucoState startHand({
    required List<Player> players,
    required List<Team> teams,
    required String openingPlayerId,
    Random? random,
    String? dealerId,
    Map<String, int>? scores,
  }) {
    _validatePlayersAndTeams(players, teams);

    final resolvedDealer = dealerId ?? _previousPlayer(players, openingPlayerId);
    var remaining = Deck.truco().shuffled(random ?? this.random ?? Random());
    final ordered = _orderedPlayers(players, openingPlayerId);
    final hands = <String, List<Card>>{};

    for (final player in ordered) {
      final draw = remaining.draw(3);
      remaining = draw.remaining;
      hands[player.id] = draw.drawn;
    }

    if (hands.values.any((cards) => cards.length != 3)) {
      throw StateError('A distribuição deve entregar exatamente 3 cartas por jogador.');
    }

    final viraDraw = remaining.draw(1);
    return newGame(
      players: players,
      teams: teams,
      deck: viraDraw.remaining,
      vira: viraDraw.drawn.single,
      hands: hands,
      openingPlayerId: openingPlayerId,
      dealerId: resolvedDealer,
      scores: scores,
    );
  }

  TrucoState newGame({
    required List<Player> players,
    required List<Team> teams,
    required Deck deck,
    required Card vira,
    required Map<String, List<Card>> hands,
    required String openingPlayerId,
    String? dealerId,
    Map<String, int>? scores,
    int handNumber = 1,
  }) {
    _validatePlayersAndTeams(players, teams);

    if (!players.any((p) => p.id == openingPlayerId)) {
      throw ArgumentError('Jogador inicial inexistente.');
    }
    final resolvedDealer = dealerId ?? _previousPlayer(players, openingPlayerId);
    if (!players.any((p) => p.id == resolvedDealer)) {
      throw ArgumentError('Distribuidor inexistente.');
    }
    final playerIds = players.map((p) => p.id).toSet();
    if (hands.length != players.length ||
        !hands.keys.toSet().containsAll(playerIds) ||
        !playerIds.containsAll(hands.keys)) {
      throw ArgumentError('O estado deve conter exatamente uma mão por jogador.');
    }

    final allHandCards = hands.values.expand((cards) => cards).toList();
    if (allHandCards.toSet().length != allHandCards.length) {
      throw ArgumentError('Uma carta não pode pertencer a dois jogadores.');
    }

    if (allHandCards.contains(vira) || allHandCards.any(deck.contains)) {
      throw ArgumentError('Cartas da mão, vira e baralho devem ser exclusivas.');
    }

    final teamScores = {
      for (final team in teams) team.id: scores?[team.id] ?? 0,
    };
    if (teamScores.values.any((score) => score < 0 || score > 11)) {
      throw ArgumentError('Placar de uma mão ativa deve estar entre 0 e 11.');
    }

    final atEleven = teams.where((t) => teamScores[t.id] == 11).toList();
    final blindHand = atEleven.length == 2;
    final phase = blindHand
        ? TrucoPhase.playing
        : atEleven.length == 1
            ? TrucoPhase.waitingElevenDecision
            : TrucoPhase.playing;

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
      dealerId: resolvedDealer,
      handNumber: handNumber,
      teamScores: teamScores,
      handValue: blindHand ? 1 : 1,
      pendingRaise: null,
      phase: phase,
      handElevenTeamId: atEleven.length == 1 ? atEleven.single.id : null,
      elevenHand: atEleven.length == 1,
      blindHand: blindHand,
      handWinnerTeamId: null,
      gameWinnerTeamId: null,
    );
  }

  @override
  TrucoState apply(TrucoState state, TrucoAction action) => switch (action) {
        PlayCard() => _play(state, action),
        RequestTruco() => _request(state, action),
        RaiseTruco() => _raise(state, action),
        AcceptTruco() => _accept(state, action),
        FoldTruco() => _fold(state, action),
        AcceptEleven() => _acceptEleven(state, action),
        FoldEleven() => _foldEleven(state, action),
        StartNextHand() => _startNextHand(state),
      };

  TrucoState _acceptEleven(TrucoState s, AcceptEleven a) {
    if (s.phase != TrucoPhase.waitingElevenDecision ||
        s.handElevenTeamId == null) {
      throw StateError('Não há decisão de Mão de Onze pendente.');
    }
    if (!_teamOf(s, a.playerId).idEquals(s.handElevenTeamId)) {
      throw StateError('Somente a equipe com 11 pode decidir.');
    }

    return s.copyWith(
      handValue: 3,
      phase: TrucoPhase.playing,
      elevenHand: true,
      clearHandElevenTeam: true,
    );
  }

  TrucoState _foldEleven(TrucoState s, FoldEleven a) {
    if (s.phase != TrucoPhase.waitingElevenDecision ||
        s.handElevenTeamId == null) {
      throw StateError('Não há decisão de Mão de Onze pendente.');
    }
    if (!_teamOf(s, a.playerId).idEquals(s.handElevenTeamId)) {
      throw StateError('Somente a equipe com 11 pode decidir.');
    }

    final elevenTeam = s.handElevenTeamId;
    final winner = s.teams.firstWhere((t) => t.id != elevenTeam);
    return _finishHand(s, winner, 1);
  }

  TrucoState _startNextHand(TrucoState s) {
    if (s.phase != TrucoPhase.handFinished) {
      throw StateError('A próxima mão só pode começar após o encerramento da atual.');
    }

    final nextDealer = _nextPlayer(s, s.dealerId);
    final nextOpening = _nextPlayer(s, nextDealer);
    return startHand(
      players: s.players,
      teams: s.teams,
      openingPlayerId: nextOpening,
      dealerId: nextDealer,
      scores: s.teamScores,
    ).copyWith(handNumber: s.handNumber + 1);
  }

  TrucoState _request(TrucoState s, RequestTruco a) {
    _playing(s);
    if (s.blindHand || s.elevenHand) {
      throw StateError('Truco não é permitido nesta mão.');
    }
    _turn(s, a.playerId);

    final expected = TrucoRules.nextValue(s.handValue);
    if (a.requestedValue != expected) {
      throw StateError('Aumento inválido.');
    }

    return s.copyWith(
      pendingRaise: TrucoRaise(
        requesterId: a.playerId,
        responderId: _nextPlayer(s, a.playerId),
        previousValue: s.handValue,
        requestedValue: a.requestedValue,
      ),
      phase: TrucoPhase.waitingTrucoResponse,
    );
  }

  TrucoState _raise(TrucoState s, RaiseTruco a) {
    final r = s.pendingRaise;
    if (s.phase != TrucoPhase.waitingTrucoResponse || r == null) {
      throw StateError('Não há pedido pendente.');
    }
    if (a.playerId != r.responderId) {
      throw StateError('Somente o respondente pode aumentar.');
    }
    if (r.requestedValue >= 12) {
      throw StateError('Doze só pode ser aceito ou recusado.');
    }

    final expected = TrucoRules.nextValue(r.requestedValue);
    if (a.requestedValue != expected) {
      throw StateError('Aumento inválido.');
    }

    return s.copyWith(
      pendingRaise: TrucoRaise(
        requesterId: a.playerId,
        responderId: r.requesterId,
        previousValue: r.requestedValue,
        requestedValue: a.requestedValue,
      ),
    );
  }

  TrucoState _accept(TrucoState s, AcceptTruco a) {
    final r = s.pendingRaise;
    if (s.phase != TrucoPhase.waitingTrucoResponse || r == null) {
      throw StateError('Não há pedido pendente.');
    }
    if (a.playerId != r.responderId) {
      throw StateError('Resposta inválida.');
    }

    return s.copyWith(
      handValue: r.requestedValue,
      clearPendingRaise: true,
      phase: TrucoPhase.playing,
      turnPlayerId: r.requesterId,
    );
  }

  TrucoState _fold(TrucoState s, FoldTruco a) {
    final r = s.pendingRaise;
    if (s.phase != TrucoPhase.waitingTrucoResponse || r == null) {
      throw StateError('Não há pedido pendente.');
    }
    if (a.playerId != r.responderId) {
      throw StateError('Resposta inválida.');
    }

    return _finishHand(s, _teamOf(s, r.requesterId), r.previousValue);
  }

  TrucoState _play(TrucoState s, PlayCard a) {
    _playing(s);
    _turn(s, a.playerId);

    final hand = s.hands[a.playerId];
    if (hand == null || !hand.contains(a.card)) {
      throw StateError('Carta não pertence à mão.');
    }

    final hands = {
      ...s.hands,
      a.playerId: [...hand]..remove(a.card),
    };

    final completedTricks =
        s.tricks.where((trick) => trick.cards.length == s.players.length).length;
    if (completedTricks >= 3) {
      throw StateError('A mão não pode ter mais de três vazas.');
    }

    final current = s.tricks.isEmpty ||
            s.tricks.last.cards.length == s.players.length
        ? Trick(number: s.currentTrick, starterId: a.playerId, cards: const [])
        : s.tricks.last;

    final cards = [
      ...current.cards,
      PlayedCard(playerId: a.playerId, card: a.card),
    ];
    final completed = cards.length == s.players.length;
    final winner = completed ? _trickWinner(s, cards) : null;

    final updated = Trick(
      number: current.number,
      starterId: current.starterId,
      cards: cards,
      winnerId: winner,
      tied: completed && winner == null,
    );

    final tricks = [...s.tricks];
    if (tricks.isEmpty || tricks.last.cards.length == s.players.length) {
      tricks.add(updated);
    } else {
      tricks[tricks.length - 1] = updated;
    }

    if (!completed) {
      return s.copyWith(
        hands: hands,
        tricks: tricks,
        turnPlayerId: _nextPlayer(s, a.playerId),
      );
    }

    final handWinner = _resolveHandWinner(s, tricks);
    if (handWinner != null) {
      return _finishHand(
        s.copyWith(hands: hands, tricks: tricks),
        _teamOf(s, handWinner),
        s.handValue,
      );
    }

    if (tricks.length == 3) {
      return _finishHandAsTie(
        s.copyWith(hands: hands, tricks: tricks),
      );
    }

    final next = updated.winnerId ?? updated.starterId;
    return s.copyWith(
      hands: hands,
      tricks: tricks,
      currentTrick: s.currentTrick + 1,
      openingPlayerId: next,
      turnPlayerId: next,
    );
  }

  TrucoState _finishHandAsTie(TrucoState s) {
    // In the standard Paulista rule modeled here, a three-vaza tie awards no
    // points. The hand simply passes to the next dealer.
    return s.copyWith(
      phase: TrucoPhase.handFinished,
      handWinnerTeamId: null,
      clearPendingRaise: true,
    );
  }

  String? _trickWinner(TrucoState s, List<PlayedCard> cards) {
    var best = cards.first;
    var bestPlayers = <PlayedCard>[best];

    for (final play in cards.skip(1)) {
      final cmp = TrucoRules.compare(best.card, play.card, s.vira);
      if (cmp < 0) {
        best = play;
        bestPlayers = [play];
      } else if (cmp == 0) {
        bestPlayers = [...bestPlayers, play];
      }
    }

    final bestTeams =
        bestPlayers.map((p) => _teamOf(s, p.playerId).id).toSet();
    if (bestTeams.length > 1) return null;
    return bestPlayers.first.playerId;
  }

  String? _resolveHandWinner(TrucoState s, List<Trick> tricks) {
    final first = tricks[0].winnerId;
    if (tricks.length >= 2) {
      final second = tricks[1].winnerId;

      if (first != null && second != null) {
        if (_teamOf(s, first).id == _teamOf(s, second).id) return first;

        if (tricks.length == 3) {
          final third = tricks[2].winnerId;
          return third ?? first;
        }
        return null;
      }

      if (first == null && second != null) return second;
      if (first != null && second == null) return first;
    }

    if (tricks.length == 3) {
      return tricks[2].winnerId;
    }
    return null;
  }

  TrucoState _finishHand(TrucoState s, Team winner, int points) {
    final scores = {...s.teamScores};
    scores[winner.id] = scores[winner.id]! + points;

    final ended = scores[winner.id]! >= 12;
    return s.copyWith(
      teamScores: scores,
      phase: ended ? TrucoPhase.gameFinished : TrucoPhase.handFinished,
      handWinnerTeamId: winner.id,
      gameWinnerTeamId: ended ? winner.id : null,
      clearPendingRaise: true,
      clearHandElevenTeam: true,
    );
  }

  Team _teamOf(TrucoState s, String playerId) =>
      s.teams.firstWhere((t) => t.playerIds.contains(playerId));

  String _nextPlayer(TrucoState s, String id) {
    return _nextPlayerFrom(s.players, id);
  }

  String _nextPlayerFrom(List<Player> players, String id) {
    final i = players.indexWhere((p) => p.id == id);
    if (i < 0) throw StateError('Jogador inexistente.');
    return players[(i + 1) % players.length].id;
  }

  String _previousPlayer(List<Player> players, String id) {
    final i = players.indexWhere((p) => p.id == id);
    if (i < 0) throw ArgumentError('Jogador inicial inexistente.');
    return players[(i - 1 + players.length) % players.length].id;
  }

  List<Player> _orderedPlayers(List<Player> players, String first) {
    final i = players.indexWhere((x) => x.id == first);
    if (i < 0) throw ArgumentError('Jogador inicial inexistente.');
    return [...players.sublist(i), ...players.sublist(0, i)];
  }

  void _turn(TrucoState s, String id) {
    if (s.turnPlayerId != id) {
      throw StateError('Não é a vez deste jogador.');
    }
  }

  void _playing(TrucoState s) {
    if (s.phase != TrucoPhase.playing) {
      throw StateError('Partida não aceita jogadas.');
    }
  }

  void _validatePlayersAndTeams(List<Player> p, List<Team> t) {
    if (p.length != 2 && p.length != 4) {
      throw ArgumentError('Truco suporta 2 ou 4 jogadores.');
    }

    final ids = p.map((x) => x.id).toSet();
    final covered = t.expand((x) => x.playerIds).toList();

    if (ids.length != p.length ||
        t.length != 2 ||
        covered.length != p.length ||
        covered.toSet().length != p.length ||
        covered.any((x) => !ids.contains(x))) {
      throw ArgumentError(
        'Times devem cobrir todos os jogadores exatamente uma vez.',
      );
    }

    final expected = p.length == 2 ? 1 : 2;
    if (t.any((x) => x.playerIds.length != expected)) {
      throw ArgumentError('Composição de times inválida.');
    }
  }
}

extension on Team {
  bool idEquals(String? other) => id == other;
}
