import 'dart:math';
import 'card.dart';
import 'rank.dart';
import 'suit.dart';

final class Deck {
  final List<Card> cards;

  const Deck(this.cards) : cards = List.unmodifiable(cards);

  factory Deck.standard() => Deck([
        for (final suit in Suit.values)
          for (final rank in Rank.values) Card(rank: rank, suit: suit),
      ]);

  Deck shuffled([Random? random]) {
    final result = [...cards];
    result.shuffle(random ?? Random());
    return Deck(result);
  }

  (Deck remaining, List<Card> drawn) draw(int count) {
    if (count < 0 || count > cards.length) {
      throw StateError('Quantidade inválida de cartas.');
    }
    return (
      Deck(cards.sublist(count)),
      List.unmodifiable(cards.sublist(0, count)),
    );
  }

  Map<String, dynamic> toJson() => {
        'cards': cards.map((card) => card.toJson()).toList(),
      };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        (json['cards'] as List)
            .map((item) => Card.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}
