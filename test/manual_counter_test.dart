import 'package:test/test.dart';
import 'package:trucaralho/games/truco/manual_truco_counter.dart';

void main() {
  test('aumento segue 1/3/6/9/12', () {
    var state = ManualTrucoCounterState();
    state = state.requestRaise();
    expect(state.handValue, 3);
    state = state.requestRaise();
    expect(state.handValue, 6);
    state = state.requestRaise();
    expect(state.handValue, 9);
    state = state.requestRaise();
    expect(state.handValue, 12);
  });

  test('não permite novo aumento depois de 12', () {
    final state = ManualTrucoCounterState(handValue: 12);
    expect(() => state.requestRaise(), throwsStateError);
  });

  test('fechamento soma o valor atual e volta a 1', () {
    final state =
        ManualTrucoCounterState(handValue: 6).closeHand(leftWinner: true);
    expect(state.leftScore, 6);
    expect(state.rightScore, 0);
    expect(state.handValue, 1);
    expect(state.finished, isFalse);
  });

  test('correr de 6 entrega 3 pontos ao solicitante', () {
    final state =
        ManualTrucoCounterState(handValue: 6).fold(leftRequester: true);
    expect(state.leftScore, 3);
    expect(state.handValue, 1);
  });

  test('correr de 3 entrega 1 ponto ao solicitante', () {
    final state =
        ManualTrucoCounterState(handValue: 3).fold(leftRequester: false);
    expect(state.leftScore, 0);
    expect(state.rightScore, 1);
  });

  test('correr de 12 entrega 9 pontos ao solicitante', () {
    final state =
        ManualTrucoCounterState(handValue: 12).fold(leftRequester: true);
    expect(state.leftScore, 9);
    expect(state.handValue, 1);
  });

  test('não é possível correr quando a mão vale 1', () {
    expect(
      () => ManualTrucoCounterState().fold(leftRequester: true),
      throwsStateError,
    );
  });

  test('contador termina ao atingir 12', () {
    final state = ManualTrucoCounterState(
      leftScore: 9,
      handValue: 3,
    ).closeHand(leftWinner: true);
    expect(state.leftScore, 12);
    expect(state.finished, isTrue);
  });

  test('contador finalizado rejeita novas operações', () {
    final state = ManualTrucoCounterState(
      leftScore: 12,
      rightScore: 8,
      finished: true,
    );

    expect(() => state.requestRaise(), throwsStateError);
    expect(() => state.closeHand(leftWinner: false), throwsStateError);
    expect(() => state.fold(leftRequester: true), throwsStateError);
    expect(() => state.add(true, 1), throwsStateError);
  });

  test('add permite ajuste manual positivo e reinicia valor da mão', () {
    final state = ManualTrucoCounterState(handValue: 6).add(false, 2);
    expect(state.leftScore, 0);
    expect(state.rightScore, 2);
    expect(state.handValue, 1);
    expect(state.finished, isFalse);
  });

  test('add rejeita pontuação não positiva', () {
    expect(
      () => ManualTrucoCounterState().add(true, 0),
      throwsArgumentError,
    );
    expect(
      () => ManualTrucoCounterState().add(false, -1),
      throwsArgumentError,
    );
  });

  test('reset volta completamente ao estado inicial', () {
    final state = ManualTrucoCounterState(
      leftScore: 7,
      rightScore: 5,
      handValue: 9,
    ).reset();
    expect(state.leftScore, 0);
    expect(state.rightScore, 0);
    expect(state.handValue, 1);
    expect(state.finished, isFalse);
  });

  test('estado manual faz round-trip por JSON', () {
    final original = ManualTrucoCounterState(
      leftScore: 7,
      rightScore: 4,
      handValue: 6,
    );
    final restored = ManualTrucoCounterState.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
  });

  test('fromJson rejeita tipos inválidos e invariantes inválidas', () {
    expect(
      () => ManualTrucoCounterState.fromJson({
        'leftScore': '7',
        'rightScore': 4,
        'handValue': 6,
        'finished': false,
      }),
      throwsFormatException,
    );
    expect(
      () => ManualTrucoCounterState(leftScore: -1),
      throwsArgumentError,
    );
    expect(
      () => ManualTrucoCounterState(handValue: 2),
      throwsArgumentError,
    );
    expect(
      () => ManualTrucoCounterState(finished: true),
      throwsArgumentError,
    );
    expect(
      () => ManualTrucoCounterState(leftScore: 12),
      throwsArgumentError,
    );
  });
}
