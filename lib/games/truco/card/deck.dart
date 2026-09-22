import 'dart:math';

import 'card.dart';
import 'rank.dart';
import 'suit.dart';

final class Deck {
  final List<Card> cards;

  const Deck(this.cards);

  factory Deck.standard() => Deck([
        for (final suit in Suit.values)
          for (final rank in Rank.values)
            Card(rank: rank, suit: suit),
      ]);

  factory Deck.truco() => Deck.standard();

  Deck shuffled([Random? random]) {
    final result = [...cards];
    result.shuffle(random ?? Random());
    return Deck(List.unmodifiable(result));
  }

  ({Deck remaining, List<Card> drawn}) draw(int count) {
    if (count < 0 || count > cards.length) {
      throw StateError('Quantidade inválida de cartas.');
    }

    return (
      remaining: Deck(List.unmodifiable(cards.sublist(count))),
      drawn: List.unmodifiable(cards.sublist(0, count)),
    );
  }

  bool contains(Card card) => cards.contains(card);

  Map<String, dynamic> toJson() => {
        'cards': cards.map((card) => card.toJson()).toList(),
      };

  factory Deck.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'];
    if (rawCards is! List) {
      throw FormatException('Baralho inválido.');
    }

    final cards = rawCards
        .map(
          (item) => Card.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    if (cards.toSet().length != cards.length) {
      throw FormatException('Baralho contém cartas duplicadas.');
    }

    return Deck(List.unmodifiable(cards));
  }
}
