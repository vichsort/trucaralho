import '../../core/game/player.dart';
import 'card/card.dart';
import 'truco_action.dart';
import 'truco_state.dart';

abstract interface class TrucoAI {
  TrucoAction chooseAction(TrucoState state, Player player);
}

final class RandomTrucoAI implements TrucoAI {
  const RandomTrucoAI();

  @override
  TrucoAction chooseAction(TrucoState state, Player player) {
    final hand = state.hands[player.id] ?? const <Card>[];
    if (hand.isEmpty) throw StateError('IA sem cartas disponíveis.');
    return PlayCard(playerId: player.id, card: hand.first);
  }
}
