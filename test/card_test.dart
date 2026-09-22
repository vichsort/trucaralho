import 'dart:math';
import 'package:test/test.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';

void main() {
  test('shuffle preserva exatamente as 40 cartas', () {
    final deck = Deck.standard();
    final shuffled = deck.shuffled(Random(42));
    expect(shuffled.cards.toSet(), deck.cards.toSet());
    expect(shuffled.cards.length, 40);
    expect(shuffled.cards, isNot(equals(deck.cards)));
  });

  test('draw remove cartas do deck e mantém as demais', () {
    final deck = Deck.standard();
    final result = deck.draw(7);
    expect(result.drawn.length, 7);
    expect(result.remaining.cards.length, 33);
    expect(result.drawn.toSet().length, 7);
  });

  test('carta não contém apresentação', () {
    const card = Card(rank: Rank.ace, suit: Suit.hearts);
    expect(card.toJson().keys, containsAll(<String>['rank', 'suit']));
    expect(card.toJson().keys, isNot(contains('imageUrl')));
  });
}
