import 'card/card.dart';
import 'card/rank.dart';
import 'card/suit.dart';

final class TrucoRules {
  static const values = [1, 3, 6, 9, 12];
  static const orderedRanks = [
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
  ];

  const TrucoRules._();

  static Rank manilhaRank(Card vira) {
    final index = orderedRanks.indexOf(vira.rank);
    return orderedRanks[(index + 1) % orderedRanks.length];
  }

  static bool isManilha(Card card, Card vira) =>
      card.rank == manilhaRank(vira);

  static int compare(Card a, Card b, Card vira) {
    final aManilha = isManilha(a, vira);
    final bManilha = isManilha(b, vira);

    if (aManilha || bManilha) {
      if (aManilha && !bManilha) return 1;
      if (!aManilha && bManilha) return -1;
      return a.suit.manilhaStrength.compareTo(b.suit.manilhaStrength);
    }

    return orderedRanks.indexOf(a.rank).compareTo(orderedRanks.indexOf(b.rank));
  }

  static int nextValue(int current) {
    final index = values.indexOf(current);
    if (index < 0 || index == values.length - 1) {
      throw StateError('Não existe aumento a partir de $current.');
    }
    return values[index + 1];
  }

  static int previousValueForFold(int requestedValue) {
    final index = values.indexOf(requestedValue);
    if (index <= 0) {
      throw StateError('Um pedido precisa representar um aumento.');
    }
    return values[index - 1];
  }
}
