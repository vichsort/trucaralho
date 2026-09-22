import 'rank.dart';
import 'suit.dart';

final class Card {
  final Rank rank;
  final Suit suit;

  const Card({required this.rank, required this.suit});

  String get id => '${rank.name}:${suit.name}';

  Map<String, dynamic> toJson() => {
        'rank': rank.name,
        'suit': suit.name,
      };

  factory Card.fromJson(Map<String, dynamic> json) => Card(
        rank: Rank.values.byName(json['rank'] as String),
        suit: Suit.values.byName(json['suit'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is Card && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => '${rank.symbol}${suit.symbol}';
}
