import 'card/card.dart';

final class PlayedCard {
  final String playerId;
  final Card card;
  const PlayedCard({required this.playerId, required this.card});

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'card': card.toJson(),
      };

  factory PlayedCard.fromJson(Map<String, dynamic> json) => PlayedCard(
        playerId: json['playerId'] as String,
        card: Card.fromJson(Map<String, dynamic>.from(json['card'] as Map)),
      );
}

final class Trick {
  final int number;
  final List<PlayedCard> cards;
  final String? winnerId;

  const Trick({
    required this.number,
    required this.cards,
    this.winnerId,
  });

  Trick copyWith({List<PlayedCard>? cards, String? winnerId}) => Trick(
        number: number,
        cards: List.unmodifiable(cards ?? this.cards),
        winnerId: winnerId ?? this.winnerId,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'cards': cards.map((card) => card.toJson()).toList(),
        'winnerId': winnerId,
      };

  factory Trick.fromJson(Map<String, dynamic> json) => Trick(
        number: json['number'] as int,
        cards: (json['cards'] as List)
            .map((item) => PlayedCard.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        winnerId: json['winnerId'] as String?,
      );
}
