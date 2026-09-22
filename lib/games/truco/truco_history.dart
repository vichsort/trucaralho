import '../../core/game/player.dart';
import 'card/card.dart';
import 'trick.dart';
import 'truco_action.dart';
import 'truco_state.dart';

final class TrucoHistoryEvent {
  final DateTime at;
  final int handNumber;
  final String type;
  final String? playerId;
  final String? teamId;
  final int? fromValue;
  final int? toValue;
  final Map<String, dynamic> data;

  const TrucoHistoryEvent({
    required this.at,
    required this.handNumber,
    required this.type,
    this.playerId,
    this.teamId,
    this.fromValue,
    this.toValue,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'handNumber': handNumber,
        'type': type,
        'playerId': playerId,
        'teamId': teamId,
        'fromValue': fromValue,
        'toValue': toValue,
        'data': data,
      };

  factory TrucoHistoryEvent.fromJson(Map<String, dynamic> json) =>
      TrucoHistoryEvent(
        at: DateTime.parse(json['at'] as String),
        handNumber: json['handNumber'] as int,
        type: json['type'] as String,
        playerId: json['playerId'] as String?,
        teamId: json['teamId'] as String?,
        fromValue: json['fromValue'] as int?,
        toValue: json['toValue'] as int?,
        data: Map<String, dynamic>.unmodifiable(
          Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
        ),
      );
}

final class TrucoHandHistory {
  final int handNumber;
  final String dealerId;
  final String openingPlayerId;
  final Map<String, int> startingScore;
  final Map<String, int> endingScore;
  final int startingValue;
  final int handValue;
  final String? winnerTeamId;
  final String outcome;
  final Card vira;
  final List<Trick> tricks;

  TrucoHandHistory({
    required this.handNumber,
    required this.dealerId,
    required this.openingPlayerId,
    required this.startingScore,
    required this.endingScore,
    required this.startingValue,
    required this.handValue,
    required this.winnerTeamId,
    required this.outcome,
    required this.vira,
    required Iterable<Trick> tricks,
  }) : tricks = List.unmodifiable(tricks);

  Map<String, dynamic> toJson() => {
        'handNumber': handNumber,
        'dealerId': dealerId,
        'openingPlayerId': openingPlayerId,
        'startingScore': startingScore,
        'endingScore': endingScore,
        'startingValue': startingValue,
        'handValue': handValue,
        'winnerTeamId': winnerTeamId,
        'outcome': outcome,
        'vira': vira.toJson(),
        'tricks': tricks.map((trick) => trick.toJson()).toList(),
      };

  factory TrucoHandHistory.fromJson(Map<String, dynamic> json) =>
      TrucoHandHistory(
        handNumber: json['handNumber'] as int,
        dealerId: json['dealerId'] as String,
        openingPlayerId: json['openingPlayerId'] as String,
        startingScore: Map<String, int>.unmodifiable(
          Map<String, int>.from(json['startingScore'] as Map),
        ),
        endingScore: Map<String, int>.unmodifiable(
          Map<String, int>.from(json['endingScore'] as Map),
        ),
        startingValue: json['startingValue'] as int,
        handValue: json['handValue'] as int,
        winnerTeamId: json['winnerTeamId'] as String?,
        outcome: json['outcome'] as String,
        vira: Card.fromJson(
          Map<String, dynamic>.from(json['vira'] as Map),
        ),
        tricks: (json['tricks'] as List)
            .map(
              (trick) => Trick.fromJson(
                Map<String, dynamic>.from(trick as Map),
              ),
            )
            .toList(),
      );
}

final class TrucoMatchHistory {
  final String game;
  final int schemaVersion;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<Player> players;
  final List<Team> teams;
  final String? winnerTeamId;
  final Map<String, int> finalScore;
  final List<TrucoHandHistory> hands;
  final List<TrucoHistoryEvent> events;

  TrucoMatchHistory({
    this.game = 'truco_paulista',
    this.schemaVersion = 1,
    required this.startedAt,
    required this.finishedAt,
    required Iterable<Player> players,
    required Iterable<Team> teams,
    required this.winnerTeamId,
    required Map<String, int> finalScore,
    required Iterable<TrucoHandHistory> hands,
    required Iterable<TrucoHistoryEvent> events,
  })  : players = List.unmodifiable(players),
        teams = List.unmodifiable(teams),
        finalScore = Map.unmodifiable(finalScore),
        hands = List.unmodifiable(hands),
        events = List.unmodifiable(events);

  Map<String, dynamic> toJson() => {
        'game': game,
        'schemaVersion': schemaVersion,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'players': players.map((player) => player.toJson()).toList(),
        'teams': teams.map((team) => team.toJson()).toList(),
        'winnerTeamId': winnerTeamId,
        'finalScore': finalScore,
        'hands': hands.map((hand) => hand.toJson()).toList(),
        'events': events.map((event) => event.toJson()).toList(),
      };

  factory TrucoMatchHistory.fromJson(Map<String, dynamic> json) =>
      TrucoMatchHistory(
        game: json['game'] as String? ?? 'truco_paulista',
        schemaVersion: json['schemaVersion'] as int? ?? 1,
        startedAt: DateTime.parse(json['startedAt'] as String),
        finishedAt: json['finishedAt'] == null
            ? null
            : DateTime.parse(json['finishedAt'] as String),
        players: (json['players'] as List)
            .map(
              (player) => Player.fromJson(
                Map<String, dynamic>.from(player as Map),
              ),
            )
            .toList(),
        teams: (json['teams'] as List)
            .map(
              (team) => Team.fromJson(
                Map<String, dynamic>.from(team as Map),
              ),
            )
            .toList(),
        winnerTeamId: json['winnerTeamId'] as String?,
        finalScore: Map<String, int>.unmodifiable(
          Map<String, int>.from(json['finalScore'] as Map),
        ),
        hands: (json['hands'] as List)
            .map(
              (hand) => TrucoHandHistory.fromJson(
                Map<String, dynamic>.from(hand as Map),
              ),
            )
            .toList(),
        events: (json['events'] as List)
            .map(
              (event) => TrucoHistoryEvent.fromJson(
                Map<String, dynamic>.from(event as Map),
              ),
            )
            .toList(),
      );
}

final class TrucoHistoryRecorder {
  final DateTime startedAt;
  final List<Player> players;
  final List<Team> teams;

  final List<TrucoHandHistory> _hands = [];
  final List<TrucoHistoryEvent> _events = [];
  late TrucoState _lastState;
  late TrucoState _currentHandStart;

  TrucoHistoryRecorder({
    required TrucoState initialState,
    DateTime? startedAt,
  })  : startedAt = startedAt ?? DateTime.now(),
        players = List.unmodifiable(initialState.players),
        teams = List.unmodifiable(initialState.teams) {
    _lastState = initialState;
    _currentHandStart = initialState;
  }

  void record({
    required TrucoState before,
    required TrucoAction action,
    required TrucoState after,
    DateTime? at,
  }) {
    final event = _eventFor(
      before: before,
      action: action,
      after: after,
      at: at ?? DateTime.now(),
    );
    _events.add(event);

    if (after.phase == TrucoPhase.handFinished ||
        after.phase == TrucoPhase.gameFinished) {
      _recordFinishedHand(after);
    }

    if (action is StartNextHand) {
      _currentHandStart = after;
    }

    _lastState = after;
  }

  TrucoMatchHistory build({DateTime? finishedAt}) {
    return TrucoMatchHistory(
      startedAt: startedAt,
      finishedAt: finishedAt,
      players: players,
      teams: teams,
      winnerTeamId: _lastState.gameWinnerTeamId,
      finalScore: Map.unmodifiable(_lastState.teamScores),
      hands: List.unmodifiable(_hands),
      events: List.unmodifiable(_events),
    );
  }

  void _recordFinishedHand(TrucoState state) {
    if (_hands.any((hand) => hand.handNumber == state.handNumber)) {
      return;
    }

    final handEvents =
        _events.where((event) => event.handNumber == state.handNumber).toList();
    final lastEvent = handEvents.isEmpty ? null : handEvents.last;

    final outcome = switch (lastEvent?.type) {
      'fold_truco' => 'truco_fold',
      'fold_eleven' => 'eleven_fold',
      _ when state.handWinnerTeamId == null => 'tricks_tied',
      _ => 'tricks',
    };

    _hands.add(
      TrucoHandHistory(
        handNumber: state.handNumber,
        dealerId: _currentHandStart.dealerId,
        openingPlayerId: _currentHandStart.openingPlayerId,
        startingScore: Map.unmodifiable(_currentHandStart.teamScores),
        endingScore: Map.unmodifiable(state.teamScores),
        startingValue: _currentHandStart.handValue,
        handValue: state.handValue,
        winnerTeamId: state.handWinnerTeamId,
        outcome: outcome,
        vira: _currentHandStart.vira,
        tricks: state.tricks,
      ),
    );
  }

  TrucoHistoryEvent _eventFor({
    required TrucoState before,
    required TrucoAction action,
    required TrucoState after,
    required DateTime at,
  }) {
    final playerId = switch (action) {
      PlayCard a => a.playerId,
      RequestTruco a => a.playerId,
      RaiseTruco a => a.playerId,
      AcceptTruco a => a.playerId,
      FoldTruco a => a.playerId,
      AcceptEleven a => a.playerId,
      FoldEleven a => a.playerId,
      StartNextHand() => null,
    };

    return TrucoHistoryEvent(
      at: at,
      handNumber: before.handNumber,
      type: action.type,
      playerId: playerId,
      teamId: playerId == null ? null : _teamId(before, playerId),
      fromValue: before.handValue,
      toValue: after.handValue,
      data: _eventData(
        before: before,
        action: action,
        after: after,
      ),
    );
  }

  Map<String, dynamic> _eventData({
    required TrucoState before,
    required TrucoAction action,
    required TrucoState after,
  }) {
    return {
      if (action is PlayCard) ...{
        'card': action.card.toJson(),
        'trickNumber': before.currentTrick,
      },
      if (action is RequestTruco) ...{
        'requestedValue': action.requestedValue,
        'previousValue': before.handValue,
        'responderId': after.pendingRaise?.responderId,
      },
      if (action is RaiseTruco) ...{
        'requestedValue': action.requestedValue,
        'previousValue': before.pendingRaise?.requestedValue,
        'responderId': after.pendingRaise?.responderId,
      },
      if (action is AcceptTruco) ...{
        'acceptedValue': before.pendingRaise?.requestedValue,
        'requesterId': before.pendingRaise?.requesterId,
      },
      if (action is FoldTruco) ...{
        'requestedValue': before.pendingRaise?.requestedValue,
        'awardedValue': before.pendingRaise?.previousValue,
        'requesterId': before.pendingRaise?.requesterId,
        'winnerTeamId': after.handWinnerTeamId,
      },
      if (action is AcceptEleven) ...{
        'acceptedValue': after.handValue,
        'teamId': after.handElevenTeamId ?? before.handElevenTeamId,
      },
      if (action is FoldEleven) ...{
        'awardedValue': after.handWinnerTeamId == null
            ? null
            : after.teamScores[after.handWinnerTeamId!]! -
                before.teamScores[after.handWinnerTeamId!]!,
        'winnerTeamId': after.handWinnerTeamId,
      },
      if (action is StartNextHand) ...{
        'dealerId': after.dealerId,
        'openingPlayerId': after.openingPlayerId,
      },
      if (after.phase == TrucoPhase.handFinished ||
          after.phase == TrucoPhase.gameFinished) ...{
        'winnerTeamId': after.handWinnerTeamId,
        'score': Map<String, int>.from(after.teamScores),
      },
    };
  }

  String? _teamId(TrucoState state, String playerId) {
    for (final team in state.teams) {
      if (team.playerIds.contains(playerId)) {
        return team.id;
      }
    }
    return null;
  }
}
