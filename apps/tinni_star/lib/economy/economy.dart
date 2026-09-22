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
  WalletService({this.coins = 2000000, this.diamonds = 17125});

  int coins;
  int diamonds;
  final List<WalletEntry> history = <WalletEntry>[];

  bool spendCoins(int amount, String label) {
    if (amount <= 0 || coins < amount) return false;
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
  });

  final String id;
  final String name;
  final int price;
  final String effectKind;
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

  bool purchase(StoreItem item) {
    if (owned.contains(item.id)) return false;
    if (!wallet.spendCoins(item.price, 'Store: ' + item.name)) return false;
    owned.add(item.id);
    return true;
  }
}
