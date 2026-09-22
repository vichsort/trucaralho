enum Rank {
  four,
  five,
  six,
  seven,
  queen,
  jack,
  king,
  ace,
  two,
  three;

  String get symbol => switch (this) {
        Rank.four => '4',
        Rank.five => '5',
        Rank.six => '6',
        Rank.seven => '7',
        Rank.queen => 'Q',
        Rank.jack => 'J',
        Rank.king => 'K',
        Rank.ace => 'A',
        Rank.two => '2',
        Rank.three => '3',
      };

  static Rank fromSymbol(String value) => values.firstWhere(
        (rank) => rank.symbol == value.toUpperCase(),
        orElse: () => throw ArgumentError('Rank inválido: $value'),
      );
}
