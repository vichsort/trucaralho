import 'truco_action.dart';
import 'truco_state.dart';
import 'trick.dart';

final class TrucoHistoryEvent {
  final String type;
  final String? playerId;
  final String? teamId;
  final int? fromValue;
  final int? toValue;
  final Map<String, dynamic> data;

  const TrucoHistoryEvent({
    required this.type,
    this.playerId,
    this.teamId,
    this.fromValue,
    this.toValue,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'playerId': playerId,
        'teamId': teamId,
        'fromValue': fromValue,
        'toValue': toValue,
        'data': data,
      };
}

final class TrucoHandHistory {
  final int handNumber;
  final int handValue;
  final String? winnerTeamId;
  final String? dealerId;
  final String? vira;
  final List<Trick> tricks;

  const TrucoHandHistory({
    required this.handNumber,
    required this.handValue,
    required this.winnerTeamId,
    required this.dealerId,
    required this.vira,
    required this.tricks,
  });

  factory TrucoHandHistory.fromState(TrucoState state) => TrucoHandHistory(
        handNumber: state.handNumber,
        handValue: state.handValue,
        winnerTeamId: state.handWinnerTeamId,
        dealerId: state.dealerId,
        vira: state.vira.toJson().toString(),
        tricks: state.tricks,
      );

  Map<String, dynamic> toJson() => {
        'handNumber': handNumber,
        'handValue': handValue,
        'winnerTeamId': winnerTeamId,
        'dealerId': dealerId,
        'vira': vira,
        'tricks': tricks.map((t) => t.toJson()).toList(),
      };
}

final class TrucoMatchHistory {
  final String game;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<String> playerIds;
  final List<String> teamIds;
  final String? winnerTeamId;
  final Map<String, int> finalScore;
  final List<TrucoHandHistory> hands;
  final List<TrucoHistoryEvent> events;

  const TrucoMatchHistory({
    this.game = 'truco_paulista',
    required this.startedAt,
    required this.finishedAt,
    required this.playerIds,
    required this.teamIds,
    required this.winnerTeamId,
    required this.finalScore,
    required this.hands,
    required this.events,
  });

  Map<String, dynamic> toJson() => {
        'game': game,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'playerIds': playerIds,
        'teamIds': teamIds,
        'winnerTeamId': winnerTeamId,
        'finalScore': finalScore,
        'hands': hands.map((h) => h.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
      };
}

final class TrucoHistoryRecorder {
  final DateTime startedAt;
  final List<String> playerIds;
  final List<String> teamIds;
  final List<TrucoHandHistory> _hands = [];
  final List<TrucoHistoryEvent> _events = [];

  TrucoHistoryRecorder({
    required TrucoState initialState,
    DateTime? startedAt,
  })  : startedAt = startedAt ?? DateTime.now(),
        playerIds = List.unmodifiable(
          initialState.players.map((p) => p.id),
        ),
        teamIds = List.unmodifiable(
          initialState.teams.map((t) => t.id),
        );

  void record({
    required TrucoState before,
    required TrucoAction action,
    required TrucoState after,
  }) {
    _events.add(
      _eventFor(action: action, before: before, after: after),
    );

    if (after.phase == TrucoPhase.handFinished ||
        after.phase == TrucoPhase.gameFinished) {
      if (_hands.every((h) => h.handNumber != after.handNumber)) {
        _hands.add(TrucoHandHistory.fromState(after));
      }
    }
  }

  TrucoMatchHistory build({DateTime? finishedAt}) {
    final finalState = _hands.isEmpty ? null : _hands.last;
    return TrucoMatchHistory(
      startedAt: startedAt,
      finishedAt: finishedAt,
      playerIds: playerIds,
      teamIds: teamIds,
      winnerTeamId: finalState?.winnerTeamId,
      finalScore: const {},
      hands: List.unmodifiable(_hands),
      events: List.unmodifiable(_events),
    );
  }

  TrucoHistoryEvent _eventFor({
    required TrucoState before,
    required TrucoAction action,
    required TrucoState after,
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

    final type = action.type;
    return TrucoHistoryEvent(
      type: type,
      playerId: playerId,
      teamId: playerId == null ? null : _teamId(after, playerId),
      fromValue: before.handValue,
      toValue: after.handValue,
      data: {
        if (action is PlayCard) 'card': action.card.toJson(),
        if (after.pendingRaise != null)
          'requestedValue': after.pendingRaise!.requestedValue,
      },
    );
  }

  String? _teamId(TrucoState state, String playerId) {
    for (final team in state.teams) {
      if (team.playerIds.contains(playerId)) return team.id;
    }
    return null;
  }
}
