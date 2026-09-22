import 'dart:math';
import 'package:test/test.dart';
import 'package:trucaralho/games/truco/card/deck.dart';
import 'package:trucaralho/games/truco/card/card.dart';
import 'package:trucaralho/games/truco/card/rank.dart';
import 'package:trucaralho/games/truco/card/suit.dart';

void main(){
  test('shuffle determinístico preserva exatamente as 40 cartas',(){
    final deck=Deck.truco();
    final a=deck.shuffled(Random(42));
    final b=deck.shuffled(Random(42));
    expect(a.cards,b.cards);
    expect(a.cards.toSet(),deck.cards.toSet());
    expect(a.cards.length,40);
  });

  test('draw remove cartas e mantém o restante',(){
    final result=Deck.truco().draw(7);
    expect(result.drawn.length,7);
    expect(result.remaining.cards.length,33);
    expect(result.drawn.toSet().length,7);
  });

  test('carta não contém apresentação',(){
    const card=Card(rank:Rank.ace,suit:Suit.hearts);
    expect(card.toJson().keys,containsAll(['rank','suit']));
    expect(card.toJson().keys,isNot(contains('imageUrl')));
  });
}
