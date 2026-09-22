abstract interface class Game<S, A> {
  S apply(S state, A action);
}

abstract interface class GameState {
  Map<String, dynamic> toJson();
}

abstract interface class GameAction {
  String get type;
}

final class GameResult {
  final bool finished;
  final String? winnerId;

  const GameResult({required this.finished, this.winnerId});
}
