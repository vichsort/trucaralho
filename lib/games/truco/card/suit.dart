enum Suit {
  diamonds,
  spades,
  hearts,
  clubs;

  int get manilhaStrength => index;

  String get symbol => switch (this) {
        Suit.diamonds => '♦',
        Suit.spades => '♠',
        Suit.hearts => '♥',
        Suit.clubs => '♣',
      };

  static Suit fromName(String value) => values.byName(value);
}
