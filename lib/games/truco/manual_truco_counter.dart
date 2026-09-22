final class ManualTrucoCounterState {
  final int leftScore;
  final int rightScore;
  final int handValue;
  final bool finished;

  ManualTrucoCounterState({
    this.leftScore = 0,
    this.rightScore = 0,
    this.handValue = 1,
    this.finished = false,
  }) {
    _validateScore(leftScore, 'leftScore');
    _validateScore(rightScore, 'rightScore');
    if (!_validValues.contains(handValue)) {
      throw ArgumentError('Valor de Truco inválido.');
    }
    if (finished && leftScore < 12 && rightScore < 12) {
      throw ArgumentError(
        'Um contador finalizado deve ter uma equipe com 12 pontos.',
      );
    }
    if (!finished && (leftScore >= 12 || rightScore >= 12)) {
      throw ArgumentError(
        'Um contador que atingiu 12 pontos deve estar finalizado.',
      );
    }
  }

  static const _validValues = {1, 3, 6, 9, 12};

  ManualTrucoCounterState requestRaise() {
    if (finished) throw StateError('Contador finalizado.');

    return copyWith(
      handValue: switch (handValue) {
        1 => 3,
        3 => 6,
        6 => 9,
        9 => 12,
        12 => throw StateError('Valor máximo atingido.'),
        _ => throw StateError('Valor inválido.'),
      },
    );
  }

  ManualTrucoCounterState closeHand({required bool leftWinner}) {
    if (finished) throw StateError('Contador finalizado.');
    return _addPoints(leftWinner, handValue);
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

    return _addPoints(leftRequester, points);
  }

  ManualTrucoCounterState add(bool left, int points) {
    if (finished) throw StateError('Contador finalizado.');
    if (points <= 0) throw ArgumentError('A pontuação deve ser positiva.');
    return _addPoints(left, points);
  }

  ManualTrucoCounterState reset() => ManualTrucoCounterState();

  ManualTrucoCounterState _addPoints(bool left, int points) {
    final nextLeft = left ? leftScore + points : leftScore;
    final nextRight = left ? rightScore : rightScore + points;
    final ended = nextLeft >= 12 || nextRight >= 12;

    return ManualTrucoCounterState(
      leftScore: nextLeft,
      rightScore: nextRight,
      handValue: 1,
      finished: ended,
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

  factory ManualTrucoCounterState.fromJson(Map<String, dynamic> json) {
    final leftScore = json['leftScore'];
    final rightScore = json['rightScore'];
    final handValue = json['handValue'];
    final finished = json['finished'];

    if (leftScore is! int ||
        rightScore is! int ||
        handValue is! int ||
        finished is! bool) {
      throw FormatException('Estado do contador manual inválido.');
    }

    return ManualTrucoCounterState(
      leftScore: leftScore,
      rightScore: rightScore,
      handValue: handValue,
      finished: finished,
    );
  }
}

void _validateScore(int score, String field) {
  if (score < 0) {
    throw ArgumentError('$field não pode ser negativo.');
  }
}
