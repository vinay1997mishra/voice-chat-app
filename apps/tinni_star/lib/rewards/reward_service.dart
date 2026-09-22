enum LuckyBagRewardKind { coins, gift, commodity }

class LuckyBagReward {
  const LuckyBagReward({
    required this.kind,
    required this.label,
    required this.amount,
  });

  final LuckyBagRewardKind kind;
  final String label;
  final int amount;
}

class LuckyBag {
  LuckyBag({
    required this.id,
    required this.senderId,
    required this.totalSlots,
    required this.reward,
  });

  final String id;
  final String senderId;
  final int totalSlots;
  final LuckyBagReward reward;
  final Set<String> claimedBy = <String>{};
  bool expired = false;

  int get remaining => totalSlots - claimedBy.length;
}

class RocketState {
  const RocketState({
    this.level = 0,
    this.progress = 0,
    this.luckMultiplier = 1,
  });

  final int level;
  final int progress;
  final int luckMultiplier;

  RocketState addProgress(int value) {
    final next = progress + value;
    final nextLevel = (next ~/ 1000).clamp(0, 5);
    final multiplier = 1 + nextLevel;
    return RocketState(
      level: nextLevel,
      progress: next,
      luckMultiplier: multiplier,
    );
  }
}

class RewardService {
  final Map<String, LuckyBag> luckyBags = <String, LuckyBag>{};
  RocketState rocket = const RocketState();
  int rebateCoins = 0;

  LuckyBag createLuckyBag({
    required String id,
    required String senderId,
    required int totalSlots,
    required LuckyBagReward reward,
  }) {
    if (id.isEmpty || senderId.isEmpty || totalSlots < 1) {
      throw StateError('Invalid lucky bag');
    }
    final bag = LuckyBag(
      id: id,
      senderId: senderId,
      totalSlots: totalSlots,
      reward: reward,
    );
    luckyBags[id] = bag;
    return bag;
  }

  LuckyBagReward? grab(String bagId, String userId) {
    final bag = luckyBags[bagId];
    if (bag == null || bag.expired || bag.remaining <= 0) return null;
    if (!bag.claimedBy.add(userId)) return null;
    return bag.reward;
  }

  void expire(String bagId) {
    luckyBags[bagId]?.expired = true;
  }

  void launchRocket(int giftValue) {
    if (giftValue <= 0) return;
    rocket = rocket.addProgress(giftValue);
  }

  void addRebate(int coins) {
    if (coins > 0) rebateCoins += coins;
  }
}
