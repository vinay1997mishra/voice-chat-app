import 'dart:io';

enum GiftLeaseV08 {
  days15,
  month1,
  months3,
  months6,
  lifetime,
}

extension GiftLeaseV08Label on GiftLeaseV08 {
  String get label {
    switch (this) {
      case GiftLeaseV08.days15:
        return '15 Days';
      case GiftLeaseV08.month1:
        return '1 Month';
      case GiftLeaseV08.months3:
        return '3 Months';
      case GiftLeaseV08.months6:
        return '6 Months';
      case GiftLeaseV08.lifetime:
        return 'Lifetime';
    }
  }

  DateTime? expiryFrom(DateTime createdAt) {
    switch (this) {
      case GiftLeaseV08.days15:
        return createdAt.add(const Duration(days: 15));
      case GiftLeaseV08.month1:
        return createdAt.add(const Duration(days: 30));
      case GiftLeaseV08.months3:
        return createdAt.add(const Duration(days: 90));
      case GiftLeaseV08.months6:
        return createdAt.add(const Duration(days: 180));
      case GiftLeaseV08.lifetime:
        return null;
    }
  }
}

List<GiftLeaseV08> roomGiftLeasesForVipV08(int vipLevel) {
  if (vipLevel >= 11) {
    return const [
      GiftLeaseV08.days15,
      GiftLeaseV08.month1,
      GiftLeaseV08.months3,
      GiftLeaseV08.months6,
      GiftLeaseV08.lifetime,
    ];
  }
  if (vipLevel >= 10) {
    return const [
      GiftLeaseV08.days15,
      GiftLeaseV08.month1,
      GiftLeaseV08.months3,
    ];
  }
  if (vipLevel >= 9) {
    return const [
      GiftLeaseV08.days15,
      GiftLeaseV08.month1,
    ];
  }
  if (vipLevel >= 8) {
    return const [GiftLeaseV08.days15];
  }
  return const [];
}

class DynamicGiftV08 {
  DynamicGiftV08({
    required this.id,
    required this.name,
    required this.coins,
    required this.videoPath,
    required this.videoBytes,
    required this.videoDuration,
    required this.lease,
    required this.createdAt,
    required this.createdBy,
    this.roomId,
    this.enabled = true,
  });

  final String id;
  final String name;
  final int coins;
  final String videoPath;
  final int videoBytes;
  final Duration videoDuration;
  final GiftLeaseV08 lease;
  final DateTime createdAt;
  final String createdBy;
  final String? roomId;
  bool enabled;

  DateTime? get expiresAt => lease.expiryFrom(createdAt);

  bool activeAt(DateTime now) {
    if (!enabled) return false;
    final expiry = expiresAt;
    return expiry == null || now.isBefore(expiry);
  }

  bool get isGlobal => roomId == null;

  String get sizeLabel =>
      (videoBytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';

  String get durationLabel =>
      videoDuration.inMilliseconds % 1000 == 0
          ? videoDuration.inSeconds.toString() + ' sec'
          : (videoDuration.inMilliseconds / 1000).toStringAsFixed(1) + ' sec';

  bool get localFileExists => File(videoPath).existsSync();
}

class DynamicGiftStoreV08 {
  final List<DynamicGiftV08> gifts = [];

  List<DynamicGiftV08> activeForRoom(String roomId, DateTime now) {
    return gifts
        .where(
          (gift) =>
              gift.activeAt(now) &&
              (gift.isGlobal || gift.roomId == roomId),
        )
        .toList();
  }

  List<DynamicGiftV08> forRoomOwner(String roomId) {
    return gifts.where((gift) => gift.roomId == roomId).toList();
  }

  void add(DynamicGiftV08 gift) {
    gifts.insert(0, gift);
  }

  void remove(String id) {
    gifts.removeWhere((gift) => gift.id == id);
  }

  void setEnabled(String id, bool enabled) {
    for (final gift in gifts) {
      if (gift.id == id) {
        gift.enabled = enabled;
        return;
      }
    }
  }
}

final dynamicGiftStoreV08 = DynamicGiftStoreV08();

const int dynamicGiftMaxVideoBytesV08 = 12 * 1024 * 1024;
const Duration dynamicGiftMaxVideoDurationV08 = Duration(seconds: 5);
