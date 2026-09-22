import 'card/card.dart';
import 'card/rank.dart';
import 'card/suit.dart';

final class TrucoRules {
  static const values = [1, 3, 6, 9, 12];

  /// Ordered from weakest to strongest.
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

  /// Returns a negative number when [a] loses to [b], zero for a tie,
  /// and a positive number when [a] beats [b].
  static int compare(Card a, Card b, Card vira) {
    final aManilha = isManilha(a, vira);
    final bManilha = isManilha(b, vira);

    if (aManilha && !bManilha) return 1;
    if (!aManilha && bManilha) return -1;

    if (aManilha) {
      return a.suit.manilhaStrength.compareTo(b.suit.manilhaStrength);
    }

    return a.rank.strength.compareTo(b.rank.strength);
  }

  static bool isValidValue(int value) => values.contains(value);

  static bool canRaise(int current) =>
      isValidValue(current) && current != values.last;

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
