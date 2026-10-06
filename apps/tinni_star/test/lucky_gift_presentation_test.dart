import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/economy/economy.dart';
import 'package:tinni_star/effects/cinematic_lane.dart';
import 'package:tinni_star/effects/lucky_combo_timer.dart';
import 'package:tinni_star/effects/lucky_gift_queue.dart';
import 'package:tinni_star/effects/lucky_gift_overlay.dart';
import 'package:tinni_star/room/room_presence_service.dart';

final gift = GiftService.luckyCatalog.first;
RoomGiftVisualEvent event({String id = 'send-one', int price = 500, int quantity = 99,
  int start = 450, int won = 510000, List<Map<String, int>>? counts,
  bool banners = true, bool ultra = true}) => RoomGiftVisualEvent(
    id: id, senderId: 'sender', senderName: 'Lucky Sender', giftId: gift.id,
    giftName: gift.name, receiverIds: const ['receiver'], quantity: quantity,
    lucky: true, multiplier: ultra ? 1000 : 20, rebateCoins: won,
    sentCoins: price * quantity, unitPrice: price,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0), visualStartedAtMs: start,
    multiplierCounts: counts ?? const [
      {'multiplier': 0, 'count': 97}, {'multiplier': 20, 'count': 1},
      {'multiplier': 1000, 'count': 1},
    ], bannersEnabled: banners, highWin: ultra, bannerWin: ultra, ultraWin: ultra,
  );

void main() {
  test('all multiplier tiers match the requested escalation', () {
    for (final n in [1, 5, 7, 9, 10]) { expect(luckyTierFor(n), LuckyBubbleTier.pop); }
    for (final n in [20, 22, 30, 50]) { expect(luckyTierFor(n), LuckyBubbleTier.glow); }
    for (final n in [75, 100]) { expect(luckyTierFor(n), LuckyBubbleTier.spark); }
    for (final n in [200, 250]) { expect(luckyTierFor(n), LuckyBubbleTier.burst); }
    expect(luckyTierFor(500), LuckyBubbleTier.premium);
    expect(luckyTierFor(750), LuckyBubbleTier.giant);
    expect(luckyTierFor(1000), LuckyBubbleTier.ultra);
  });

  test('500 coin unit times 20 returns 10000 and rare results beyond 32 are queued', () {
    final presentation = LuckyGiftPresentation(event: event(), gift: gift, startedAtMs: 450);
    expect(presentation.completeResults, isTrue);
    expect(presentation.zeroCount, 97);
    expect(presentation.results.map((row) => row.multiplier), [20, 1000]);
    expect(presentation.results.first.coins, 10000);
    expect(presentation.durationMs, 4900);
    expect(presentation.frameAt(1050)!.result!.multiplier, 20);
    expect(presentation.frameAt(1750)!.result!.multiplier, 1000);
    expect(presentation.frameAt(3950)!.revealedCoins, 510000);
    expect(presentation.frameAt(5350), isNull);
  });

  test('large batches retain every result as explicit repeated-win counts', () {
    final presentation = LuckyGiftPresentation(
      event: event(quantity: 7999, won: 500 * 750 * 7999,
        counts: const [{'multiplier': 750, 'count': 7999}]),
      gift: gift, startedAtMs: 450,
    );
    expect(presentation.completeResults, isTrue);
    expect(presentation.results.single.count, 7999);
    expect(presentation.results.single.coins, 500 * 750 * 7999);
    expect(presentation.durationMs, 3800);
  });

  test('late peers use the same timeline and duplicate delivery never repeats', () {
    var now = 0;
    final first = LuckyGiftQueue(clock: () => now);
    final second = LuckyGiftQueue(clock: () => now);
    first.add(event(), gift);
    now = 1500;
    second.add(event(), gift);
    expect(second.add(event(), gift), isFalse);
    now = 1800;
    final a = first.pending.first.frameAt(now)!;
    final b = second.pending.first.frameAt(now)!;
    expect(a.result!.multiplier, b.result!.multiplier);
    expect(a.progress, b.progress);
    expect(a.revealedCoins, b.revealedCoins);
    first.add(event(id: 'second', start: 5350), gift);
    now = 5350; first.prune();
    expect(first.pending.single.event.id, 'second');
    first.dispose(); second.dispose();
  });

  testWidgets('Combo renews only on success and hides exactly nine seconds later', (tester) async {
    var now = DateTime.utc(2026, 10, 6);
    final timer = LuckyComboTimer(clock: () => now);
    void success(String session) => timer.success(gift: gift.id,
      receiverIds: ['b', 'a'], session: session, sendQuantity: 9,
      totalCount: 9, totalWon: 18000, totalSent: 4500, highestMultiplier: 20);
    success('session');
    expect(timer.secondsLeft, 9);
    now = now.add(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 8));
    expect(timer.continues(gift.id, ['a', 'b']), isTrue);
    expect(timer.continues(gift.id, ['different']), isFalse);
    expect(timer.secondsLeft, 1);
    success('session');
    expect(timer.secondsLeft, 9);
    // A failed request does not call success and cannot extend this deadline.
    now = now.add(const Duration(seconds: 9));
    await tester.pump(const Duration(seconds: 9));
    expect(timer.active, isFalse);
    expect(timer.sessionId, isNull);
    expect(timer.count, 0);
    timer.dispose();
  });

  testWidgets('center HUD shows actual quantity, sent and won with one sequential bubble', (tester) async {
    var now = 450;
    final queue = LuckyGiftQueue(clock: () => now)..add(event(), gift);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LuckyGiftOverlay(queue: queue))));
    expect(find.byKey(const Key('lucky-center-banner')), findsOneWidget);
    expect(find.text('Gift ×99'), findsOneWidget);
    expect(find.text('510,000'), findsOneWidget);
    now = 1200; await tester.pump(const Duration(milliseconds: 750));
    expect(find.byKey(const Key('lucky-active-multiplier')), findsOneWidget);
    expect(find.text('×20'), findsOneWidget);
    expect(find.text('×1000'), findsNothing);
    now = 1900; await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('×20'), findsNothing);
    expect(find.text('×1000'), findsOneWidget);
    expect(find.byKey(const Key('lucky-fullscreen-celebration')), findsOneWidget);
    now = 4100; await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('Sent: 49,500  →  Won: 510,000'), findsOneWidget);
    now = 5350; await tester.pump(const Duration(milliseconds: 1250));
    expect(find.byKey(const Key('lucky-center-banner')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
  });

  testWidgets('zero return has no win effect and Owner banner disable is respected', (tester) async {
    var now = 1200;
    final queue = LuckyGiftQueue(clock: () => now)..add(event(quantity: 9,
      won: 0, ultra: false, counts: const [{'multiplier': 0, 'count': 9}]), gift);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LuckyGiftOverlay(queue: queue))));
    expect(find.text('×0'), findsOneWidget);
    expect(find.text('0× · No return this send'), findsOneWidget);
    expect(find.byKey(const Key('lucky-fullscreen-celebration')), findsNothing);
    expect(find.byKey(const Key('lucky-big-win-banner')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
    final disabled = LuckyGiftQueue(clock: () => now)..add(event(banners: false), gift);
    now = 1900;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LuckyGiftOverlay(queue: disabled))));
    expect(find.text('×1000'), findsOneWidget);
    expect(find.byKey(const Key('lucky-fullscreen-celebration')), findsNothing);
    expect(find.byKey(const Key('lucky-big-win-banner')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    disabled.dispose();
  });

  testWidgets('Rocket and flag presentations keep their foreground during Lucky celebrations', (tester) async {
    var now = 1900;
    final queue = LuckyGiftQueue(clock: () => now)..add(event(), gift);
    final lane = CinematicLane(); final rocket = Object();
    lane.acquire(rocket);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LuckyGiftOverlay(queue: queue, lane: lane))));
    expect(find.byKey(const Key('lucky-center-banner')), findsOneWidget);
    expect(find.text('×1000'), findsOneWidget);
    expect(find.byKey(const Key('lucky-fullscreen-celebration')), findsNothing);
    lane.release(rocket); await tester.pump();
    expect(find.byKey(const Key('lucky-fullscreen-celebration')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    queue.dispose(); lane.dispose();
  });

  testWidgets('background resume follows shared clock and reduced motion keeps totals', (tester) async {
    var now = 1900;
    final queue = LuckyGiftQueue(clock: () => now)..add(event(), gift);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: LuckyGiftOverlay(queue: queue)))));
    expect(find.text('×1000'), findsOneWidget);
    expect(find.byKey(const Key('lucky-fullscreen-celebration')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byKey(const Key('lucky-center-banner')), findsNothing);
    now = 6000;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('lucky-center-banner')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    queue.dispose();
  });
}
