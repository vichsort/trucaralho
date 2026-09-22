import 'package:test/test.dart';
import 'package:trucaralho/games/truco/manual_truco_counter.dart';

void main(){
  test('aumento segue 1/3/6/9/12',(){
    var s=const ManualTrucoCounterState();
    s=s.requestRaise();expect(s.handValue,3);
    s=s.requestRaise();expect(s.handValue,6);
    s=s.requestRaise();expect(s.handValue,9);
    s=s.requestRaise();expect(s.handValue,12);
  });

  test('fechamento soma o valor atual e volta a 1',(){
    final s=const ManualTrucoCounterState(handValue:6).closeHand(leftWinner:true);
    expect(s.leftScore,6);
    expect(s.handValue,1);
  });

  test('correr de 6 entrega 3 pontos ao solicitante',(){
    final s=const ManualTrucoCounterState(handValue:6).fold(leftRequester:true);
    expect(s.leftScore,3);
    expect(s.handValue,1);
  });

  test('contador termina ao atingir 12',(){
    final s=const ManualTrucoCounterState(leftScore:9,handValue:3).closeHand(leftWinner:true);
    expect(s.leftScore,12);
    expect(s.finished,isTrue);
  });
}
