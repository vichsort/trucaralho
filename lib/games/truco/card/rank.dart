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

  /// Strength used for non-manilha cards. Higher is stronger.
  int get strength => switch (this) {
        Rank.four => 0,
        Rank.five => 1,
        Rank.six => 2,
        Rank.seven => 3,
        Rank.queen => 4,
        Rank.jack => 5,
        Rank.king => 6,
        Rank.ace => 7,
        Rank.two => 8,
        Rank.three => 9,
      };

  static Rank fromSymbol(String value) => values.firstWhere(
        (rank) => rank.symbol == value.toUpperCase(),
        orElse: () => throw ArgumentError('Rank inválido: $value'),
      );
}
