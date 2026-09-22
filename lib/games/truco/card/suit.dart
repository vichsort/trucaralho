enum Suit {
  diamonds,
  spades,
  hearts,
  clubs;

  /// Strength used when two manilhas have the same rank.
  /// Paulista order: Ouros < Espadas < Copas < Paus.
  int get manilhaStrength => switch (this) {
        Suit.diamonds => 0,
        Suit.spades => 1,
        Suit.hearts => 2,
        Suit.clubs => 3,
      };

  String get symbol => switch (this) {
        Suit.diamonds => '♦',
        Suit.spades => '♠',
        Suit.hearts => '♥',
        Suit.clubs => '♣',
      };

  static Suit fromName(String value) => values.byName(value);
}
