import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/discovery/discovery_service.dart';

import 'test_account.dart';

void main() {
  TinniState makeState() {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    final account = attachTestAccount(state);
    state.discovery.rooms.add(
      RoomSummary(
        id: account.userId,
        title: 'My Room',
        country: account.countryCode,
        countryName: account.countryName,
        flagEmoji: account.flagEmoji,
        online: 1,
        seatCount: 12,
        partyMode: 'Friends-making Party',
        createdAt: DateTime.now(),
        ownerId: account.userId,
        ownerName: account.displayName,
        ownerFlagEmoji: account.flagEmoji,
      ),
    );
    return state;
  }

  test('real owner room keeps creator public ID as room ID', () {
    const ownerId = '91000001';
    final room = RoomSummary(
      id: ownerId,
      title: 'My Room',
      country: 'IN',
      online: 1,
      ownerId: ownerId,
    );

    expect(room.id, ownerId);
    expect(room.ownerId, ownerId);
  });

  testWidgets('room photo button opens Gallery and Camera choices',
      (tester) async {
    final state = makeState();
    state.discovery.rooms.clear();

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('top-tab-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mine-create-my-room')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-room-photo-button')));
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.byKey(const Key('create-room-photo-gallery')), findsOneWidget);
    expect(find.byKey(const Key('create-room-photo-camera')), findsOneWidget);
  });

  testWidgets('room has no platform owner/admin panel button',
      (tester) async {
    final state = makeState();
    final roomId = state.discovery.rooms.single.id;

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    final roomCard = find.byKey(Key('room-card-' + roomId));
    await tester.ensureVisible(roomCard);
    await tester.pumpAndSettle();
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);
    expect(find.byIcon(Icons.admin_panel_settings_rounded), findsNothing);
  });
}
