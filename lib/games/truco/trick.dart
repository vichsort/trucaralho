import 'card/card.dart';

final class PlayedCard {
  final String playerId;
  final Card card;
  const PlayedCard({required this.playerId, required this.card});

  Map<String,dynamic> toJson()=>{'playerId':playerId,'card':card.toJson()};

  factory PlayedCard.fromJson(Map<String,dynamic> json)=>PlayedCard(
    playerId:json['playerId'] as String,
    card:Card.fromJson(Map<String,dynamic>.from(json['card'] as Map)),
  );
}

final class Trick {
  final int number;
  final String starterId;
  final List<PlayedCard> cards;
  final String? winnerId;
  final bool tied;

  Trick({
    required this.number,
    required this.starterId,
    required Iterable<PlayedCard> cards,
    this.winnerId,
    this.tied=false,
  }):cards=List.unmodifiable(cards);

  Trick copyWith({Iterable<PlayedCard>? cards,String? winnerId,bool? tied})=>Trick(
    number:number,starterId:starterId,cards:cards??this.cards,
    winnerId:winnerId??this.winnerId,tied:tied??this.tied,
  );

  Map<String,dynamic> toJson()=>{
    'number':number,'starterId':starterId,
    'cards':cards.map((c)=>c.toJson()).toList(),
    'winnerId':winnerId,'tied':tied,
  };

  factory Trick.fromJson(Map<String,dynamic> json)=>Trick(
    number:json['number'] as int,
    starterId:json['starterId'] as String,
    cards:(json['cards'] as List).map((c)=>PlayedCard.fromJson(Map<String,dynamic>.from(c as Map))),
    winnerId:json['winnerId'] as String?,
    tied:(json['tied'] as bool?)??false,
  );
}
