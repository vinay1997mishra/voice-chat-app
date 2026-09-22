import 'economy.dart';

class BackpackItem {
  const BackpackItem({
    required this.giftId,
    required this.quantity,
  });

  final String giftId;
  final int quantity;

  BackpackItem copyWith({int? quantity}) => BackpackItem(
        giftId: giftId,
        quantity: quantity ?? this.quantity,
      );
}

class BackpackService {
  final Map<String, BackpackItem> items = <String, BackpackItem>{};

  void add(String giftId, int quantity) {
    if (quantity <= 0) return;
    final current = items[giftId];
    items[giftId] = BackpackItem(
      giftId: giftId,
      quantity: (current?.quantity ?? 0) + quantity,
    );
  }

  bool consume(String giftId, int quantity) {
    final current = items[giftId];
    if (current == null || quantity <= 0 || current.quantity < quantity) {
      return false;
    }
    final left = current.quantity - quantity;
    if (left == 0) {
      items.remove(giftId);
    } else {
      items[giftId] = current.copyWith(quantity: left);
    }
    return true;
  }
}

class GiftAtlasEntry {
  const GiftAtlasEntry({
    required this.giftId,
    required this.obtainedCount,
  });

  final String giftId;
  final int obtainedCount;
}

class GiftAtlasService {
  final Map<String, int> _counts = <String, int>{};

  void recordObtained(String giftId, {int count = 1}) {
    if (count <= 0) return;
    _counts[giftId] = (_counts[giftId] ?? 0) + count;
  }

  List<GiftAtlasEntry> entries() => _counts.entries
      .map(
        (entry) => GiftAtlasEntry(
          giftId: entry.key,
          obtainedCount: entry.value,
        ),
      )
      .toList();
}

class GiftComboSession {
  GiftComboSession({
    required this.gift,
    required this.receiverId,
  });

  final GiftDefinition gift;
  final String receiverId;
  int count = 0;

  void add(int amount, {required int maxCombo}) {
    if (amount <= 0) return;
    count = (count + amount).clamp(0, maxCombo);
  }
}

class GiftBannerEvent {
  const GiftBannerEvent({
    required this.sender,
    required this.receiver,
    required this.giftName,
    required this.quantity,
  });

  final String sender;
  final String receiver;
  final String giftName;
  final int quantity;
}
