import 'package:test/test.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';
import 'package:trucaralho/games/truco/truco_rules.dart';
import 'package:trucaralho/games/truco/card/deck.dart';

void main() {
  test('baralho possui 40 cartas sem duplicatas', () {
    final deck = Deck.standard();
    expect(deck.cards.length, 40);
    expect(deck.cards.toSet().length, 40);
  });

  test('ordem das cartas comuns é a do Truco Paulista', () {
    const vira = Card(rank: Rank.four, suit: Suit.diamonds);
    expect(TrucoRules.compare(
      const Card(rank: Rank.three, suit: Suit.diamonds),
      const Card(rank: Rank.two, suit: Suit.diamonds),
      vira,
    ), greaterThan(0));
    expect(TrucoRules.compare(
      const Card(rank: Rank.two, suit: Suit.diamonds),
      const Card(rank: Rank.ace, suit: Suit.diamonds),
      vira,
    ), greaterThan(0));
  });

  test('manilha é a carta seguinte à vira', () {
    const vira = Card(rank: Rank.seven, suit: Suit.diamonds);
    expect(TrucoRules.manilhaRank(vira), Rank.queen);
    expect(TrucoRules.isManilha(
      const Card(rank: Rank.queen, suit: Suit.clubs), vira), isTrue);
  });

  test('manilhas desempata por Ouros < Espadas < Copas < Paus', () {
    const vira = Card(rank: Rank.seven, suit: Suit.diamonds);
    const ouro = const Card(rank: Rank.queen, suit: Suit.diamonds);
    const espadas = const Card(rank: Rank.queen, suit: Suit.spades);
    final copas = const Card(rank: Rank.queen, suit: Suit.hearts);
    final paus = const Card(rank: Rank.queen, suit: Suit.clubs);
    expect(TrucoRules.compare(ouro, espadas, vira), lessThan(0));
    expect(TrucoRules.compare(espadas, copas, vira), lessThan(0));
    expect(TrucoRules.compare(copas, paus, vira), lessThan(0));
  });

  test('próximo valor segue 1, 3, 6, 9, 12', () {
    expect(TrucoRules.nextValue(1), 3);
    expect(TrucoRules.nextValue(3), 6);
    expect(TrucoRules.nextValue(6), 9);
    expect(TrucoRules.nextValue(9), 12);
  });

  test('corrida de pedido para 6 vale os 3 pontos vigentes', () {
    expect(TrucoRules.previousValueForFold(6), 3);
  });
}
