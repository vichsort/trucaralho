import 'dart:math';

import 'package:test/test.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';
import 'package:trucaralho/games/truco/truco_rules.dart';

void main() {
  test('baralho de Truco possui exatamente as 40 cartas únicas', () {
    final deck = Deck.truco();

    expect(deck.cards.length, 40);
    expect(deck.cards.toSet().length, 40);
    expect(
      {for (final card in deck.cards) card.rank},
      equals(Rank.values.toSet()),
    );
    expect(
      {for (final card in deck.cards) card.suit},
      equals(Suit.values.toSet()),
    );
  });

  test('shuffle determinístico preserva exatamente as 40 cartas', () {
    final deck = Deck.truco();
    final a = deck.shuffled(Random(42));
    final b = deck.shuffled(Random(42));

    expect(a.cards, b.cards);
    expect(a.cards.toSet(), deck.cards.toSet());
    expect(a.cards.length, 40);
  });

  test('draw remove cartas e mantém o restante', () {
    final result = Deck.truco().draw(7);

    expect(result.drawn.length, 7);
    expect(result.remaining.cards.length, 33);
    expect(result.drawn.toSet().length, 7);
    expect(
      [...result.drawn, ...result.remaining.cards].toSet().length,
      40,
    );
  });

  test('draw rejeita quantidade inválida', () {
    expect(() => Deck.truco().draw(-1), throwsStateError);
    expect(() => Deck.truco().draw(41), throwsStateError);
  });

  test('deserialização rejeita cartas duplicadas', () {
    const card = Card(rank: Rank.ace, suit: Suit.hearts);

    expect(
      () => Deck.fromJson({
        'cards': [card.toJson(), card.toJson()],
      }),
      throwsFormatException,
    );
  });

  test('carta não contém apresentação', () {
    const card = Card(rank: Rank.ace, suit: Suit.hearts);

    expect(card.toJson().keys, containsAll(['rank', 'suit']));
    expect(card.toJson().keys, isNot(contains('imageUrl')));
  });

  test('hierarquia de ranks é explicitamente a do Truco Paulista', () {
    expect(
      TrucoRules.orderedRanks,
      equals([
        Rank.four,
        Rank.five,
        Rank.six,
        Rank.seven,
        Rank.queen,
        Rank.jack,
        Rank.king,
        Rank.ace,
        Rank.two,
        Rank.three,
      ]),
    );

    for (var i = 0; i < TrucoRules.orderedRanks.length - 1; i++) {
      expect(
        TrucoRules.orderedRanks[i].strength,
        lessThan(TrucoRules.orderedRanks[i + 1].strength),
      );
    }
  });

  test('hierarquia das manilhas usa ordem explícita de naipes', () {
    expect(Suit.diamonds.manilhaStrength, 0);
    expect(Suit.spades.manilhaStrength, 1);
    expect(Suit.hearts.manilhaStrength, 2);
    expect(Suit.clubs.manilhaStrength, 3);

    const vira = Card(rank: Rank.seven, suit: Suit.diamonds);

    expect(
      TrucoRules.compare(
        const Card(rank: Rank.queen, suit: Suit.clubs),
        const Card(rank: Rank.queen, suit: Suit.hearts),
        vira,
      ),
      greaterThan(0),
    );
    expect(
      TrucoRules.compare(
        const Card(rank: Rank.queen, suit: Suit.diamonds),
        const Card(rank: Rank.queen, suit: Suit.spades),
        vira,
      ),
      lessThan(0),
    );
  });

  test('manilha é sempre o rank seguinte ao vira, inclusive no ciclo 3 -> 4', () {
    for (var i = 0; i < TrucoRules.orderedRanks.length; i++) {
      final vira = Card(
        rank: TrucoRules.orderedRanks[i],
        suit: Suit.diamonds,
      );
      final expected = TrucoRules.orderedRanks[
        (i + 1) % TrucoRules.orderedRanks.length
      ];

      expect(TrucoRules.manilhaRank(vira), expected);
    }
  });

  test('valores de Truco formam somente 1 -> 3 -> 6 -> 9 -> 12', () {
    expect(TrucoRules.values, equals([1, 3, 6, 9, 12]));

    expect(TrucoRules.isValidValue(1), isTrue);
    expect(TrucoRules.isValidValue(2), isFalse);
    expect(TrucoRules.canRaise(9), isTrue);
    expect(TrucoRules.canRaise(12), isFalse);
    expect(TrucoRules.nextValue(1), 3);
    expect(TrucoRules.nextValue(3), 6);
    expect(TrucoRules.nextValue(6), 9);
    expect(TrucoRules.nextValue(9), 12);
    expect(() => TrucoRules.nextValue(12), throwsStateError);
    expect(TrucoRules.previousValueForFold(3), 1);
    expect(TrucoRules.previousValueForFold(12), 9);
    expect(() => TrucoRules.previousValueForFold(1), throwsStateError);
  });
}
