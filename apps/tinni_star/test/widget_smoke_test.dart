import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/discovery/discovery_service.dart';

import 'test_account.dart';

void main() {
  testWidgets('authenticated real user opens real room and renders seat grid',
      (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    final account = attachTestAccount(state);
    state.discovery.rooms.add(
      RoomSummary(
        id: account.userId,
        title: 'My Real Room',
        country: account.countryCode,
        countryName: account.countryName,
        flagEmoji: account.flagEmoji,
        online: 1,
        seatCount: 12,
        createdAt: DateTime.now(),
        ownerId: account.userId,
        ownerName: account.displayName,
        ownerFlagEmoji: account.flagEmoji,
      ),
    );

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('My Real Room'), findsWidgets);

    final roomCard = find.byKey(Key('room-card-' + account.userId));
    await tester.ensureVisible(roomCard);
    await tester.pumpAndSettle();
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);

    await tester.tap(find.byTooltip('Minimize room'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mini-room-bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-room-bar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);
  });
}
