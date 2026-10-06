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
  int coinSellerUsdCents = 0;
  int merchantUsdCents = 0;
  bool coinSellerActive = false;
  bool merchantActive = false;
  bool coinSellerFrozen = false;
  bool merchantFrozen = false;
  final List<WalletEntry> history = <WalletEntry>[];

  String get diamondUsdText =>
      '\$' + (diamondUsdCents / 100).toStringAsFixed(2);
  String get withdrawableUsdText =>
      '\$' + (withdrawableUsdCents / 100).toStringAsFixed(2);

  int _remoteUpdatedAt = 0;
  String? _remoteUserId;
  void applyRemote(RemoteWallet remote) {
    if (remote.userId != null && remote.userId != _remoteUserId) {
      _remoteUserId = remote.userId;
      _remoteUpdatedAt = 0;
    }
    if (remote.updatedAt > 0 && remote.updatedAt < _remoteUpdatedAt) return;
    if (remote.updatedAt > _remoteUpdatedAt) _remoteUpdatedAt = remote.updatedAt;
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
    coinSellerUsdCents = remote.coinSellerWallet?.usdCents ?? 0;
    merchantUsdCents = remote.merchantWallet?.usdCents ?? 0;
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
    this.kind = '',
    this.durationDays = 0,
    this.assetUrl = '',
  });

  final String id;
  final String name;
  final int price;
  final String type;
  final String kind;
  final int durationDays;
  final String assetUrl;

  bool get permanent => durationDays <= 0;
}

class InventoryService {
  InventoryService(this.wallet);

  final WalletService wallet;
  final Set<String> owned = <String>{};
  final Map<String, Map<String, dynamic>> ownedDetails =
      <String, Map<String, dynamic>>{};
  final Map<String, String?> equippedByKind = <String, String?>{};
  String? equippedFrameId;

  void applyRemote(Map<String, dynamic> data) {
    final rawOwned = data['owned'];
    final rows = rawOwned is List
        ? rawOwned
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    owned
      ..clear()
      ..addAll(
        rows
            .map((row) => row['item_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      );
    ownedDetails
      ..clear()
      ..addEntries(
        rows.map((row) {
          final id = row['item_id']?.toString() ?? '';
          return MapEntry(id, row);
        }).where((entry) => entry.key.isNotEmpty),
      );

    equippedByKind
      ..clear()
      ..addAll(<String, String?>{
        'frame': _validEquipped(data['equipped_frame_id']),
        'vehicle': _validEquipped(data['equipped_vehicle_id']),
        'entry': _validEquipped(data['equipped_entry_id']),
        'profile_card': _validEquipped(data['equipped_profile_card_id']),
        'ring': _validEquipped(data['equipped_ring_id']),
        'bubble': _validEquipped(data['equipped_bubble_id']),
        'profile_background':
            _validEquipped(data['equipped_profile_background_id']),
      });
    equippedFrameId = equippedByKind['frame'];
  }

  String? _validEquipped(dynamic value) {
    final id = value?.toString() ?? '';
    return id.isNotEmpty && owned.contains(id) ? id : null;
  }

  bool get hasEquippedFrame =>
      equippedFrameId != null && owned.contains(equippedFrameId);

  String? equipped(String kind) => equippedByKind[kind];

  bool isEquipped(String kind, String itemId) =>
      equippedByKind[kind] == itemId;

  void applyEquipped(String kind, String? itemId) {
    final normalized =
        itemId != null && itemId.isNotEmpty && owned.contains(itemId)
            ? itemId
            : null;
    equippedByKind[kind] = normalized;
    if (kind == 'frame') equippedFrameId = normalized;
  }

  bool equipFrame(String frameId) {
    if (!owned.contains(frameId)) return false;
    applyEquipped('frame', frameId);
    return true;
  }

  void removeFrame() {
    applyEquipped('frame', null);
  }

  bool purchase(StoreItem item) {
    if (owned.contains(item.id)) return false;
    if (!wallet.spendCoins(item.price, 'Store: ' + item.name)) return false;
    owned.add(item.id);
    return true;
  }
}
