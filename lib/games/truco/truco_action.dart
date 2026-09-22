import '../../core/game/game_action.dart';
import 'card/card.dart';

sealed class TrucoAction implements GameAction {
  const TrucoAction();
}

final class PlayCard extends TrucoAction {
  final String playerId;
  final Card card;
  const PlayCard({required this.playerId, required this.card});
  @override String get type => 'play_card';
}

final class RequestTruco extends TrucoAction {
  final String playerId;
  final int requestedValue;
  const RequestTruco({required this.playerId, required this.requestedValue});
  @override String get type => 'request_truco';
}

final class AcceptTruco extends TrucoAction {
  final String playerId;
  const AcceptTruco(this.playerId);
  @override String get type => 'accept_truco';
}

final class FoldTruco extends TrucoAction {
  final String playerId;
  const FoldTruco(this.playerId);
  @override String get type => 'fold_truco';
}
