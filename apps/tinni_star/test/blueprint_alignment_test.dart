import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/discovery/discovery_service.dart';

void main() {
  TinniState makeState() {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    state.auth.loginDemo();
    return state;
  }

  test('created room uses creator public ID as room ID', () {
    final discovery = DiscoveryService();
    final room = discovery.createRoom(
      title: 'My Room',
      country: 'IN',
      ownerId: '10000000',
    );

    expect(room.id, '10000000');
    expect(room.ownerId, '10000000');
  });

  testWidgets('room photo button opens Gallery and Camera choices',
      (tester) async {
    final state = makeState();
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
    expect(
      find.byKey(const Key('create-room-photo-gallery')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('create-room-photo-camera')),
      findsOneWidget,
    );
  });

  testWidgets('room has no platform owner/admin panel button and gift users swipe',
      (tester) async {
    final state = makeState();
    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    final roomCard = find.byKey(const Key('room-card-1524843'));
    await tester.ensureVisible(roomCard);
    await tester.pumpAndSettle();
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);
    expect(find.byIcon(Icons.admin_panel_settings_rounded), findsNothing);

    await tester.tap(find.byKey(const Key('room-gift-button')));
    await tester.pumpAndSettle();

    final strip = find.byKey(const Key('gift-recipient-strip'));
    expect(strip, findsOneWidget);
    final list = tester.widget<ListView>(
      find.descendant(of: strip, matching: find.byType(ListView)),
    );
    expect(list.scrollDirection, Axis.horizontal);
  });

  testWidgets('apply-mic seat tap does not auto-approve the user',
      (tester) async {
    final state = makeState();
    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    final roomCard = find.byKey(const Key('room-card-1524843'));
    await tester.ensureVisible(roomCard);
    await tester.pumpAndSettle();
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    final firstSeat = find.byKey(const Key('seat-0'));
    expect(firstSeat, findsOneWidget);
    await tester.tap(firstSeat);
    await tester.pumpAndSettle();

    expect(state.roomSession.controller?.inviteMode, isTrue);
    expect(state.roomSession.controller?.mySeat, isNull);
  });
}
