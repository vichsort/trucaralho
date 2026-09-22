import 'card/card.dart';
import 'trick.dart';

final class TrucoHandHistory {
  final int handValue;
  final String? winnerTeamId;
  final List<Trick> tricks;

  const TrucoHandHistory({
    required this.handValue,
    required this.winnerTeamId,
    required this.tricks,
  });

  Map<String, dynamic> toJson() => {
        'handValue': handValue,
        'winnerTeamId': winnerTeamId,
        'tricks': tricks.map((t) => t.toJson()).toList(),
      };
}

final class TrucoMatchHistory {
  final String game;
  final DateTime finishedAt;
  final List<String> playerIds;
  final List<String> teamIds;
  final Map<String, int> finalScore;
  final List<TrucoHandHistory> hands;
  final List<String> events;

  const TrucoMatchHistory({
    required this.game,
    required this.finishedAt,
    required this.playerIds,
    required this.teamIds,
    required this.finalScore,
    required this.hands,
    required this.events,
  });

  Map<String, dynamic> toJson() => {
        'game': game,
        'finishedAt': finishedAt.toIso8601String(),
        'playerIds': playerIds,
        'teamIds': teamIds,
        'finalScore': finalScore,
        'hands': hands.map((h) => h.toJson()).toList(),
        'events': events,
      };
}
