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

    await tester.tap(find.byKey(const Key('room-power-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minimize'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mini-room-bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-room-bar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);
  });

  testWidgets(
      'room tool tiles open the function panel matching their labels',
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

    final roomCard = find.byKey(Key('room-card-' + account.userId));
    await tester.ensureVisible(roomCard);
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    Future<void> expectToolOpens(String toolKey, Key panelKey) async {
      await tester.tap(find.byKey(const Key('room-tools-grid-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(toolKey)));
      await tester.pumpAndSettle();
      expect(find.byKey(panelKey), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await expectToolOpens(
      'room-tool-gift',
      const Key('room-gift-panel'),
    );
    await expectToolOpens(
      'room-tool-music',
      const Key('room-music-panel'),
    );
    await expectToolOpens(
      'room-tool-lucky-bag',
      const Key('room-lucky-bag-panel'),
    );
    await expectToolOpens(
      'room-tool-moderation',
      const Key('room-moderation-panel'),
    );
  });

}
