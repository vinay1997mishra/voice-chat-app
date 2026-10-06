import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Only a successful send renews the nine-second server-send window.
class LuckyComboTimer extends ChangeNotifier {
  LuckyComboTimer({DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  static const window = Duration(seconds: 9);
  final DateTime Function() clock;
  DateTime? _expiresAt;
  Timer? _timer;
  String? giftId;
  Set<String> recipients = {};
  String? sessionId;
  int quantity = 1;
  int count = 0;
  int wonCoins = 0;
  int sentCoins = 0;
  int highest = 0;
  bool get active => _expiresAt != null && clock().isBefore(_expiresAt!);
  int get secondsLeft => active ? math.max(0, (_expiresAt!.difference(clock()).inMilliseconds / 1000).ceil()) : 0;
  bool continues(String gift, List<String> receiverIds) =>
      active && giftId == gift && recipients.length == receiverIds.toSet().length &&
      recipients.containsAll(receiverIds);

  void success({required String gift, required List<String> receiverIds,
    required String session, required int sendQuantity, required int totalCount,
    required int totalWon, required int totalSent, required int highestMultiplier}) {
    giftId = gift; recipients = Set.unmodifiable(receiverIds); sessionId = session;
    quantity = sendQuantity; count = totalCount; wonCoins = totalWon;
    sentCoins = totalSent; highest = highestMultiplier;
    _expiresAt = clock().add(window);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!active) clear(); else notifyListeners();
    });
    notifyListeners();
  }

  void clear() {
    _timer?.cancel(); _timer = null; _expiresAt = null;
    giftId = null; recipients = {}; sessionId = null;
    quantity = 1; count = 0; wonCoins = 0; sentCoins = 0; highest = 0;
    notifyListeners();
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}
