final class ManualTrucoCounterState {
  final int leftScore;
  final int rightScore;
  final int handValue;
  final bool finished;

  const ManualTrucoCounterState({
    this.leftScore = 0,
    this.rightScore = 0,
    this.handValue = 1,
    this.finished = false,
  });

  ManualTrucoCounterState requestRaise() {
    if (finished) throw StateError('Contador finalizado.');
    return copyWith(
      handValue: switch (handValue) {
        1 => 3,
        3 => 6,
        6 => 9,
        9 => 12,
        _ => throw StateError('Valor máximo atingido.'),
      },
    );
  }

  ManualTrucoCounterState closeHand({required bool leftWinner}) {
    if (finished) throw StateError('Contador finalizado.');

    final points = handValue;
    final nextLeft = leftWinner ? leftScore + points : leftScore;
    final nextRight = leftWinner ? rightScore : rightScore + points;
    final ended = nextLeft >= 12 || nextRight >= 12;

    return copyWith(
      leftScore: nextLeft,
      rightScore: nextRight,
      handValue: 1,
      finished: ended,
    );
  }

  ManualTrucoCounterState fold({required bool leftRequester}) {
    if (finished || handValue == 1) {
      throw StateError('Não há aumento pendente.');
    }

    final points = switch (handValue) {
      3 => 1,
      6 => 3,
      9 => 6,
      12 => 9,
      _ => throw StateError('Valor inválido.'),
    };

    return _addPoints(
      leftRequester ? true : false,
      points,
    );
  }

  ManualTrucoCounterState add(bool left, int points) {
    if (finished) throw StateError('Contador finalizado.');
    if (points <= 0) throw ArgumentError('A pontuação deve ser positiva.');
    return _addPoints(left, points);
  }

  ManualTrucoCounterState _addPoints(bool left, int points) {
    final nextLeft = left ? leftScore + points : leftScore;
    final nextRight = left ? rightScore : rightScore + points;
    final ended = nextLeft >= 12 || nextRight >= 12;

    return copyWith(
      leftScore: nextLeft,
      rightScore: nextRight,
      finished: ended,
      handValue: 1,
    );
  }

  ManualTrucoCounterState copyWith({
    int? leftScore,
    int? rightScore,
    int? handValue,
    bool? finished,
  }) =>
      ManualTrucoCounterState(
        leftScore: leftScore ?? this.leftScore,
        rightScore: rightScore ?? this.rightScore,
        handValue: handValue ?? this.handValue,
        finished: finished ?? this.finished,
      );

  Map<String, dynamic> toJson() => {
        'leftScore': leftScore,
        'rightScore': rightScore,
        'handValue': handValue,
        'finished': finished,
      };
}
