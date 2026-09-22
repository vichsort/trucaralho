import '../../core/game/game.dart';
import '../../core/game/player.dart';
import 'card/card.dart';
import 'card/deck.dart';
import 'trick.dart';

enum TrucoPhase {
  waitingElevenDecision,
  waitingTrucoResponse,
  playing,
  handFinished,
  gameFinished,
}

final class TrucoRaise {
  final String requesterId;
  final String responderId;
  final int previousValue;
  final int requestedValue;

  const TrucoRaise({
    required this.requesterId,
    required this.responderId,
    required this.previousValue,
    required this.requestedValue,
  });

  Map<String, dynamic> toJson() => {
        'requesterId': requesterId,
        'responderId': responderId,
        'previousValue': previousValue,
        'requestedValue': requestedValue,
      };

  factory TrucoRaise.fromJson(Map<String, dynamic> json) => TrucoRaise(
        requesterId: json['requesterId'] as String,
        responderId: json['responderId'] as String,
        previousValue: json['previousValue'] as int,
        requestedValue: json['requestedValue'] as int,
      );
}

final class TrucoState implements GameState {
  final List<Player> players;
  final List<Team> teams;
  final Deck deck;
  final Card vira;
  final Map<String, List<Card>> hands;
  final List<Trick> tricks;
  final int currentTrick;
  final String turnPlayerId;
  final String openingPlayerId;
  final String dealerId;
  final int handNumber;
  final Map<String, int> teamScores;
  final int handValue;
  final TrucoRaise? pendingRaise;
  final TrucoPhase phase;
  final String? handElevenTeamId;
  final bool elevenHand;
  final bool blindHand;
  final String? handWinnerTeamId;
  final String? gameWinnerTeamId;

  const TrucoState({
    required this.players,
    required this.teams,
    required this.deck,
    required this.vira,
    required this.hands,
    required this.tricks,
    required this.currentTrick,
    required this.turnPlayerId,
    required this.openingPlayerId,
    required this.dealerId,
    required this.handNumber,
    required this.teamScores,
    required this.handValue,
    required this.pendingRaise,
    required this.phase,
    required this.handElevenTeamId,
    required this.elevenHand,
    required this.blindHand,
    required this.handWinnerTeamId,
    required this.gameWinnerTeamId,
  });

  TrucoState copyWith({
    List<Player>? players,
    List<Team>? teams,
    Deck? deck,
    Card? vira,
    Map<String, List<Card>>? hands,
    List<Trick>? tricks,
    int? currentTrick,
    String? turnPlayerId,
    String? openingPlayerId,
    String? dealerId,
    int? handNumber,
    Map<String, int>? teamScores,
    int? handValue,
    TrucoRaise? pendingRaise,
    bool clearPendingRaise = false,
    TrucoPhase? phase,
    String? handElevenTeamId,
    bool clearHandElevenTeam = false,
    bool? elevenHand,
    bool? blindHand,
    String? handWinnerTeamId,
    bool clearHandWinner = false,
    String? gameWinnerTeamId,
  }) =>
      TrucoState(
        players: List.unmodifiable(players ?? this.players),
        teams: List.unmodifiable(teams ?? this.teams),
        deck: deck ?? this.deck,
        vira: vira ?? this.vira,
        hands: Map<String, List<Card>>.unmodifiable(
          (hands ?? this.hands).map(
            (key, value) => MapEntry(key, List<Card>.unmodifiable(value)),
          ),
        ),
        tricks: List.unmodifiable(tricks ?? this.tricks),
        currentTrick: currentTrick ?? this.currentTrick,
        turnPlayerId: turnPlayerId ?? this.turnPlayerId,
        openingPlayerId: openingPlayerId ?? this.openingPlayerId,
        dealerId: dealerId ?? this.dealerId,
        handNumber: handNumber ?? this.handNumber,
        teamScores: Map<String, int>.unmodifiable(teamScores ?? this.teamScores),
        handValue: handValue ?? this.handValue,
        pendingRaise:
            clearPendingRaise ? null : (pendingRaise ?? this.pendingRaise),
        phase: phase ?? this.phase,
        handElevenTeamId: clearHandElevenTeam
            ? null
            : (handElevenTeamId ?? this.handElevenTeamId),
        elevenHand: elevenHand ?? this.elevenHand,
        blindHand: blindHand ?? this.blindHand,
        handWinnerTeamId:
            clearHandWinner ? null : (handWinnerTeamId ?? this.handWinnerTeamId),
        gameWinnerTeamId: gameWinnerTeamId ?? this.gameWinnerTeamId,
      );

  @override
  Map<String, dynamic> toJson() => {
        'players': players.map((p) => p.toJson()).toList(),
        'teams': teams.map((t) => t.toJson()).toList(),
        'deck': deck.toJson(),
        'vira': vira.toJson(),
        'hands': hands.map(
          (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
        ),
        'tricks': tricks.map((t) => t.toJson()).toList(),
        'currentTrick': currentTrick,
        'turnPlayerId': turnPlayerId,
        'openingPlayerId': openingPlayerId,
        'dealerId': dealerId,
        'handNumber': handNumber,
        'teamScores': teamScores,
        'handValue': handValue,
        'pendingRaise': pendingRaise?.toJson(),
        'phase': phase.name,
        'handElevenTeamId': handElevenTeamId,
        'elevenHand': elevenHand,
        'blindHand': blindHand,
        'handWinnerTeamId': handWinnerTeamId,
        'gameWinnerTeamId': gameWinnerTeamId,
      };

  factory TrucoState.fromJson(Map<String, dynamic> json) => TrucoState(
        players: (json['players'] as List)
            .map((p) => Player.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
        teams: (json['teams'] as List)
            .map((t) => Team.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
        deck: Deck.fromJson(Map<String, dynamic>.from(json['deck'] as Map)),
        vira: Card.fromJson(Map<String, dynamic>.from(json['vira'] as Map)),
        hands: (json['hands'] as Map).map(
          (k, v) => MapEntry(
            k as String,
            (v as List)
                .map(
                  (c) => Card.fromJson(
                    Map<String, dynamic>.from(c as Map),
                  ),
                )
                .toList(),
          ),
        ),
        tricks: (json['tricks'] as List)
            .map((t) => Trick.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
        currentTrick: json['currentTrick'] as int,
        turnPlayerId: json['turnPlayerId'] as String,
        openingPlayerId: json['openingPlayerId'] as String,
        dealerId: json['dealerId'] as String,
        handNumber: json['handNumber'] as int,
        teamScores: Map<String, int>.from(json['teamScores'] as Map),
        handValue: json['handValue'] as int,
        pendingRaise: json['pendingRaise'] == null
            ? null
            : TrucoRaise.fromJson(
                Map<String, dynamic>.from(json['pendingRaise'] as Map),
              ),
        phase: TrucoPhase.values.byName(json['phase'] as String),
        handElevenTeamId: json['handElevenTeamId'] as String?,
        elevenHand: json['elevenHand'] as bool? ?? false,
        blindHand: json['blindHand'] as bool? ?? false,
        handWinnerTeamId: json['handWinnerTeamId'] as String?,
        gameWinnerTeamId: json['gameWinnerTeamId'] as String?,
      );
}
