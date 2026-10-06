import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/discovery/discovery_service.dart';
import 'package:tinni_star/effects/gift_scene_overlay.dart';
import 'package:tinni_star/effects/lucky_gift_overlay.dart';
import 'package:tinni_star/effects/rocket_launch.dart';
import 'package:tinni_star/room/room_presence_service.dart';
import 'test_account.dart';

void main() {
  testWidgets('actual RoomScreen accepts its own Lucky event and keeps earlier effects and comments', (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(signatureVerifier: const DevelopmentSignatureVerifier()),
      roomPresenceFallbackTimerEnabled: false,
    );
    final account = attachTestAccount(state, userId: '94000031');
    final now = DateTime.now();
    state.discovery.rooms.add(RoomSummary(
      id: account.userId, title: 'Lucky HUD room', country: account.countryCode,
      countryName: account.countryName, flagEmoji: account.flagEmoji,
      online: 2, seatCount: 12, createdAt: now,
      ownerId: account.userId, ownerName: account.displayName,
    ));
    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();
    final room = find.byKey(Key('room-card-${account.userId}'));
    await tester.ensureVisible(room); await tester.tap(room);
    await tester.pumpAndSettle();
    final event = RoomGiftVisualEvent(
      id: 'own-lucky-event', senderId: account.userId, senderName: account.displayName,
      giftId: 'lucky-colorful-rose', giftName: 'Colorful Rose',
      receiverIds: const ['94000032'], quantity: 9, lucky: true, multiplier: 20,
      rebateCoins: 18000, sentCoins: 4500, unitPrice: 500, createdAt: now,
      visualStartedAtMs: state.roomPresence.serverNowMs - 1,
      multiplierCounts: const [
        {'multiplier': 0, 'count': 5}, {'multiplier': 1, 'count': 1},
        {'multiplier': 5, 'count': 1}, {'multiplier': 10, 'count': 1},
        {'multiplier': 20, 'count': 1},
      ],
    );
    state.roomPresence.giftVisualEvents.add(event);
    state.roomPresence.latestGiftVisualEvent = event;
    state.roomPresence.notifyListeners();
    await tester.pump(); await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(LuckyGiftOverlay), findsOneWidget);
    expect(find.byKey(const Key('lucky-center-banner')), findsOneWidget);
    expect(find.text('Gift ×9'), findsOneWidget);
    expect(find.text('18,000'), findsOneWidget);
    expect(find.byType(RocketLaunchOverlay), findsOneWidget);
    expect(find.byType(GiftSceneOverlay), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('room-message-list'))).height, greaterThan(0));
    final lucky = tester.widget<LuckyGiftOverlay>(find.byType(LuckyGiftOverlay));
    expect(lucky.queue.pending.length, 1);
    state.roomPresence.notifyListeners(); await tester.pump();
    expect(lucky.queue.pending.length, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox()); await tester.pump();
  });
}
