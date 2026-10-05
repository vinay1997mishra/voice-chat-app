import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/discovery/discovery_service.dart';
import 'package:tinni_star/economy/premium_gift_catalog.dart';
import 'package:tinni_star/effects/gift_scene_overlay.dart';
import 'package:tinni_star/room/room_presence_service.dart';
import 'test_account.dart';

void main() {
  testWidgets('country flag shrinks to the actual off-mic receiver ID and DP',
      (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(signatureVerifier: const DevelopmentSignatureVerifier()),
      roomPresenceFallbackTimerEnabled: false,
    );
    final account = attachTestAccount(state, userId: '94000021');
    final now = DateTime.now();
    state.roomPresence.members.add(RoomPresenceMember(
      userId: '94000022', displayName: 'Receiver off mic',
      joinedAt: now, lastSeen: now,
    ));
    state.discovery.rooms.add(RoomSummary(
      id: account.userId, title: 'Flag receiver room',
      country: account.countryCode, countryName: account.countryName,
      flagEmoji: account.flagEmoji, online: 2, seatCount: 12, createdAt: now,
      ownerId: account.userId, ownerName: account.displayName,
    ));
    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();
    final roomCard = find.byKey(Key('room-card-' + account.userId));
    await tester.ensureVisible(roomCard);
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('room-message-list'))).height, greaterThan(0));
    final overlay = tester.widget<GiftSceneOverlay>(find.byType(GiftSceneOverlay));
    overlay.queue.add(GiftSceneEvent(
      gift: PremiumGiftCatalog.find('flag-in')!, recipients: ['94000022'],
    ));
    await tester.pump();
    expect(find.byKey(const Key('country-recipient-landing-94000022')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    final flight = find.byKey(const Key('country-flag-flight-94000022'));
    final target = find.byKey(const Key('country-recipient-dp-94000022'));
    expect(flight, findsOneWidget);
    expect(target, findsOneWidget);
    expect(find.byKey(const Key('country-recipient-landing-94000021')), findsNothing);
    final start = tester.getRect(flight);
    final startDistance = (start.center - tester.getCenter(target)).distance;
    await tester.pump(const Duration(milliseconds: 800));
    final approaching = tester.getRect(flight);
    expect(approaching.width, lessThan(start.width));
    expect((approaching.center - tester.getCenter(target)).distance, lessThan(startDistance));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('country-recipient-landing-94000022')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('room-message-list'))).height, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
