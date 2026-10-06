import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../economy/economy.dart';
import '../room/room_presence_service.dart';

enum LuckyBubbleTier { pop, glow, spark, burst, premium, giant, ultra }

LuckyBubbleTier luckyTierFor(int multiplier) {
  if (multiplier >= 1000) return LuckyBubbleTier.ultra;
  if (multiplier >= 750) return LuckyBubbleTier.giant;
  if (multiplier >= 500) return LuckyBubbleTier.premium;
  if (multiplier >= 200) return LuckyBubbleTier.burst;
  if (multiplier >= 75) return LuckyBubbleTier.spark;
  if (multiplier >= 20) return LuckyBubbleTier.glow;
  return LuckyBubbleTier.pop;
}

int luckyBubbleDurationMs(int multiplier) {
  switch (luckyTierFor(multiplier)) {
    case LuckyBubbleTier.ultra: return 2200;
    case LuckyBubbleTier.giant: return 1800;
    case LuckyBubbleTier.premium: return 1400;
    case LuckyBubbleTier.burst: return 1100;
    case LuckyBubbleTier.spark: return 920;
    case LuckyBubbleTier.glow: return 700;
    case LuckyBubbleTier.pop: return multiplier == 0 ? 620 : 540;
  }
}

class LuckyBubbleResult {
  const LuckyBubbleResult(this.multiplier, this.count, this.coins);
  final int multiplier;
  final int count;
  final int coins;
  int get durationMs => luckyBubbleDurationMs(multiplier);
}

class LuckyPresentationFrame {
  const LuckyPresentationFrame(this.result, this.progress, this.revealedCoins, this.elapsedMs);
  final LuckyBubbleResult? result;
  final double progress;
  final int revealedCoins;
  final int elapsedMs;
}

class LuckyGiftPresentation {
  LuckyGiftPresentation({
    required this.event, required this.gift, required this.startedAtMs,
  }) {
    final counts = <int, int>{};
    for (final row in event.multiplierCounts) {
      final multiplier = row['multiplier']!;
      counts[multiplier] = (counts[multiplier] ?? 0) + row['count']!;
    }
    zeroCount = counts[0] ?? 0;
    final ordered = counts.keys.where((value) => value > 0).toList()..sort();
    final wins = ordered.fold<int>(0, (sum, value) => sum + counts[value]!);
    final computed = counts.entries.fold<int>(0,
        (sum, row) => sum + row.key * row.value * event.unitPrice);
    completeResults = counts.isNotEmpty && event.unitPrice > 0 &&
        computed == event.rebateCoins &&
        counts.values.fold<int>(0, (sum, n) => sum + n) == event.quantity * event.receiverIds.length;
    if (completeResults) {
      for (final multiplier in ordered) {
        final count = counts[multiplier]!;
        if (wins <= 32) {
          for (var i = 0; i < count; i++) {
            results.add(LuckyBubbleResult(multiplier, 1, event.unitPrice * multiplier));
          }
        } else {
          results.add(LuckyBubbleResult(multiplier, count, event.unitPrice * multiplier * count));
        }
      }
      if (results.isEmpty) results.add(LuckyBubbleResult(0, zeroCount, 0));
    } else {
      // Older servers expose only a batch summary. Never invent unseen rolls.
      results.add(LuckyBubbleResult(event.rebateCoins > 0 ? event.multiplier : 0, 1, event.rebateCoins));
    }
    computedDurationMs = 600 + results.fold<int>(0, (sum, row) => sum + row.durationMs) + 1400;
  }

  final RoomGiftVisualEvent event;
  final GiftDefinition gift;
  final int startedAtMs;
  final List<LuckyBubbleResult> results = [];
  late final int zeroCount;
  late final bool completeResults;
  late final int computedDurationMs;
  int get durationMs => event.visualDurationMs > 0 ? event.visualDurationMs : computedDurationMs;
  int get endsAtMs => startedAtMs + durationMs;

  LuckyPresentationFrame? frameAt(int nowMs) {
    if (nowMs < startedAtMs || nowMs >= endsAtMs) return null;
    final elapsed = nowMs - startedAtMs;
    var cursor = elapsed - 600;
    if (cursor < 0) return LuckyPresentationFrame(null, 0, 0, elapsed);
    var coins = 0;
    for (final result in results) {
      if (cursor < result.durationMs) {
        final progress = cursor / result.durationMs;
        return LuckyPresentationFrame(result, progress,
          coins + (result.coins * math.min(1, progress * 3)).floor(), elapsed);
      }
      cursor -= result.durationMs;
      coins += result.coins;
    }
    return LuckyPresentationFrame(null, 1, event.rebateCoins, elapsed);
  }
}

/// One bubble at a time, using the server's shared room schedule.
class LuckyGiftQueue extends ChangeNotifier {
  LuckyGiftQueue({int Function()? clock})
      : clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  final int Function() clock;
  final _pending = <LuckyGiftPresentation>[];
  final _seen = <String>{};
  UnmodifiableListView<LuckyGiftPresentation> get pending => UnmodifiableListView(_pending);

  bool add(RoomGiftVisualEvent event, GiftDefinition gift) {
    if (!event.lucky || event.id.isEmpty || !_seen.add(event.id)) return false;
    final start = event.visualStartedAtMs > 0 ? event.visualStartedAtMs :
        math.max(clock() + 450, _pending.isEmpty ? 0 : _pending.last.endsAtMs);
    final presentation = LuckyGiftPresentation(event: event, gift: gift, startedAtMs: start);
    if (presentation.endsAtMs <= clock()) return false;
    _pending.add(presentation);
    _pending.sort((a, b) => a.startedAtMs.compareTo(b.startedAtMs));
    notifyListeners();
    return true;
  }

  void prune() => _pending.removeWhere((event) => event.endsAtMs <= clock());
  void clear() {
    _pending.clear();
    _seen.clear();
    notifyListeners();
  }
}
