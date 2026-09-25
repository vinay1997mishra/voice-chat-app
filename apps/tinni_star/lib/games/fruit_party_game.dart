enum FruitPartyKind {
  lemon('🍋', 'Lemon', 5),
  raspberry('🫐', 'Raspberry', 5),
  kiwi('🥝', 'Kiwi', 5),
  plum('🍑', 'Plum', 5),
  banana('🍌', 'Banana', 10),
  strawberry('🍓', 'Strawberry', 15),
  watermelon('🍉', 'Watermelon', 25),
  cherry('🍒', 'Cherry', 45);

  const FruitPartyKind(this.emoji, this.label, this.multiplier);

  final String emoji;
  final String label;
  final int multiplier;
}

class FruitPartyRoundResult {
  const FruitPartyRoundResult({
    required this.roundId,
    required this.fruit,
    required this.totalBet,
    required this.totalPayout,
    required this.activePlayers,
    required this.settledAt,
    this.specialKind,
    this.bonusFruits = const <FruitPartyKind>[],
  });

  final int roundId;
  final FruitPartyKind fruit;
  final int totalBet;
  final int totalPayout;
  final int activePlayers;
  final DateTime settledAt;
  final String? specialKind;
  final List<FruitPartyKind> bonusFruits;

  bool get isLucky11 => specialKind == 'lucky11';
}
