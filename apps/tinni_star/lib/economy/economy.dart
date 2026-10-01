import '../infra/app_backend_service.dart';

enum CurrencyKind { coins, diamonds }

class WalletEntry {
  const WalletEntry({
    required this.label,
    required this.amount,
    required this.currency,
  });

  final String label;
  final int amount;
  final CurrencyKind currency;
}

class WalletService {
  WalletService({this.coins = 0, this.diamonds = 0});

  int coins;
  int diamonds;
  bool diamondWalletVisible = false;
  bool isHost = false;
  bool isAgency = false;
  bool isBd = false;
  int diamondUsdCents = 0;
  int commissionUsdCents = 0;
  int withdrawableUsdCents = 0;
  bool canTransferSettlement = false;
  bool securityFrozen = false;
  String freezeReason = '';
  int coinSellerBalance = 0;
  int merchantBalance = 0;
  bool coinSellerActive = false;
  bool merchantActive = false;
  bool coinSellerFrozen = false;
  bool merchantFrozen = false;
  final List<WalletEntry> history = <WalletEntry>[];

  String get diamondUsdText =>
      '\$' + (diamondUsdCents / 100).toStringAsFixed(2);
  String get withdrawableUsdText =>
      '\$' + (withdrawableUsdCents / 100).toStringAsFixed(2);

  void applyRemote(RemoteWallet remote) {
    coins = remote.coins;
    diamonds = remote.diamonds;
    diamondWalletVisible = remote.diamondWalletVisible;
    isHost = remote.isHost;
    isAgency = remote.isAgency;
    isBd = remote.isBd;
    diamondUsdCents = remote.diamondUsdCents;
    commissionUsdCents = remote.commissionUsdCents;
    withdrawableUsdCents = remote.withdrawableUsdCents;
    canTransferSettlement = remote.canTransferSettlement;
    securityFrozen = remote.securityFrozen;
    freezeReason = remote.freezeReason;
    coinSellerActive = remote.coinSellerWallet != null;
    merchantActive = remote.merchantWallet != null;
    coinSellerBalance = remote.coinSellerWallet?.balance ?? 0;
    merchantBalance = remote.merchantWallet?.balance ?? 0;
    coinSellerFrozen = remote.coinSellerWallet?.securityFrozen ?? false;
    merchantFrozen = remote.merchantWallet?.securityFrozen ?? false;
  }

  bool spendCoins(int amount, String label) {
    if (securityFrozen || amount <= 0 || coins < amount) return false;
    coins -= amount;
    history.insert(
      0,
      WalletEntry(label: label, amount: -amount, currency: CurrencyKind.coins),
    );
    return true;
  }

  void creditCoins(int amount, String label) {
    if (amount <= 0) return;
    coins += amount;
    history.insert(
      0,
      WalletEntry(label: label, amount: amount, currency: CurrencyKind.coins),
    );
  }

  void creditDiamonds(int amount, String label) {
    if (amount <= 0) return;
    diamonds += amount;
    history.insert(
      0,
      WalletEntry(
        label: label,
        amount: amount,
        currency: CurrencyKind.diamonds,
      ),
    );
  }
}

class GiftDefinition {
  const GiftDefinition({
    required this.id,
    required this.name,
    required this.price,
    required this.effectKind,
    this.lucky = false,
    this.emoji = '🎁',
    this.maxMultiplier = 0,
    this.artworkAsset,
  });

  final String id;
  final String name;
  final int price;
  final String effectKind;
  final bool lucky;
  final String emoji;
  final int maxMultiplier;
  final String? artworkAsset;
}

class GiftTransaction {
  const GiftTransaction({
    required this.gift,
    required this.quantity,
    required this.senderId,
    required this.receiverIds,
    required this.totalCost,
  });

  final GiftDefinition gift;
  final int quantity;
  final String senderId;
  final List<String> receiverIds;
  final int totalCost;
}

class GiftService {
  GiftService(this.wallet);

  final WalletService wallet;
  final List<GiftTransaction> sent = <GiftTransaction>[];

  static const catalog = [
    GiftDefinition(id: 'rose', name: 'Rose', price: 100, effectKind: 'svga'),
    GiftDefinition(
      id: 'crystal',
      name: 'Crystal',
      price: 500,
      effectKind: 'pag',
    ),
    GiftDefinition(id: 'crown', name: 'Crown', price: 1000, effectKind: 'mp4'),
  ];

  static const luckyCatalog = <GiftDefinition>[
    GiftDefinition(
      id: 'lucky-colorful-rose',
      name: 'Colorful Rose',
      price: 20,
      effectKind: 'lucky',
      lucky: true,
      emoji: '🌈🌹',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/colorful_rose.webp',
    ),
    GiftDefinition(
      id: 'lucky-rainbow-heart',
      name: 'Rainbow Heart',
      price: 50,
      effectKind: 'lucky',
      lucky: true,
      emoji: '🌈💖',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/rainbow_heart.webp',
    ),
    GiftDefinition(
      id: 'lucky-magic-balloon',
      name: 'Magic Balloon',
      price: 100,
      effectKind: 'lucky',
      lucky: true,
      emoji: '🎈',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/magic_balloon.webp',
    ),
    GiftDefinition(
      id: 'lucky-candy-star',
      name: 'Candy Star',
      price: 200,
      effectKind: 'lucky',
      lucky: true,
      emoji: '🍭⭐',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/candy_star.webp',
    ),
    GiftDefinition(
      id: 'lucky-neon-butterfly',
      name: 'Neon Butterfly',
      price: 500,
      effectKind: 'lucky',
      lucky: true,
      emoji: '🦋',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/neon_butterfly.webp',
    ),
    GiftDefinition(
      id: 'lucky-sparkle-crown',
      name: 'Sparkle Crown',
      price: 1000,
      effectKind: 'lucky',
      lucky: true,
      emoji: '👑',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/sparkle_crown.webp',
    ),
    GiftDefinition(
      id: 'lucky-dream-cake',
      name: 'Dream Cake',
      price: 2000,
      effectKind: 'lucky',
      lucky: true,
      emoji: '🎂',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/dream_cake.webp',
    ),
    GiftDefinition(
      id: 'lucky-galaxy-ring',
      name: 'Galaxy Ring',
      price: 5000,
      effectKind: 'lucky',
      lucky: true,
      emoji: '💍',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/galaxy_ring.webp',
    ),
    GiftDefinition(
      id: 'lucky-shining-unicorn',
      name: 'Shining Unicorn',
      price: 10000,
      effectKind: 'lucky',
      lucky: true,
      emoji: '🦄',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/shining_unicorn.webp',
    ),
    GiftDefinition(
      id: 'lucky-royal-treasure',
      name: 'Royal Treasure Box',
      price: 20000,
      effectKind: 'lucky',
      lucky: true,
      emoji: '🎁',
      maxMultiplier: 1000,
      artworkAsset: 'assets/lucky_gifts/royal_treasure.webp',
    ),
  ];

  GiftTransaction? send({
    required GiftDefinition gift,
    required int quantity,
    required int maxCombo,
    required String senderId,
    required List<String> receiverIds,
  }) {
    if (quantity < 1 ||
        quantity > maxCombo ||
        receiverIds.isEmpty ||
        senderId.isEmpty) {
      return null;
    }
    final total = gift.price * quantity * receiverIds.length;
    if (!wallet.spendCoins(total, 'Gift: ' + gift.name)) return null;
    final transaction = GiftTransaction(
      gift: gift,
      quantity: quantity,
      senderId: senderId,
      receiverIds: List<String>.unmodifiable(receiverIds),
      totalCost: total,
    );
    sent.insert(0, transaction);
    return transaction;
  }
}

class StoreItem {
  const StoreItem({
    required this.id,
    required this.name,
    required this.price,
    required this.type,
  });

  final String id;
  final String name;
  final int price;
  final String type;
}

class InventoryService {
  InventoryService(this.wallet);

  final WalletService wallet;
  final Set<String> owned = <String>{};
  String? equippedFrameId;

  void applyRemote(Map<String, dynamic> data) {
    final rawOwned = data['owned'];
    owned
      ..clear()
      ..addAll(
        rawOwned is List
            ? rawOwned
                .whereType<Map>()
                .map((row) => row['item_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
            : const <String>[],
      );
    final remoteFrame = data['equipped_frame_id']?.toString();
    equippedFrameId =
        remoteFrame != null && remoteFrame.isNotEmpty && owned.contains(remoteFrame)
            ? remoteFrame
            : null;
  }

  bool get hasEquippedFrame =>
      equippedFrameId != null && owned.contains(equippedFrameId);

  bool equipFrame(String frameId) {
    if (!owned.contains(frameId)) return false;
    equippedFrameId = frameId;
    return true;
  }

  void removeFrame() {
    equippedFrameId = null;
  }

  bool purchase(StoreItem item) {
    if (owned.contains(item.id)) return false;
    if (!wallet.spendCoins(item.price, 'Store: ' + item.name)) return false;
    owned.add(item.id);
    return true;
  }
}
