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
    state.discovery.rooms.addAll([
      RoomSummary(
        id: account.userId,
        title: 'My Real Room',
        country: account.countryCode,
        online: 1,
        createdAt: DateTime.now(),
        ownerId: account.userId,
        ownerName: account.displayName,
        ownerFlagEmoji: account.flagEmoji,
      ),
      RoomSummary(
        id: '92000001',
        title: 'Friend Room',
        country: 'US',
        online: 4,
        createdAt: DateTime.now(),
        ownerId: '92000001',
        ownerName: 'Friend',
        ownerFlagEmoji: '🇺🇸',
      ),
    ]);
    state.discovery.visit('92000001');
    state.discovery.toggleFavorite('92000001');
    return state;
  }

  testWidgets(
    'top Mine is room-focused and separate from bottom profile Mine',
    (tester) async {
      final state = makeState();

      await tester.pumpWidget(TinniStarApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('top-tab-0')));
      await tester.pumpAndSettle();

      expect(find.text('My room'), findsOneWidget);
      expect(find.text('My Real Room'), findsOneWidget);
      expect(find.text('Recents'), findsOneWidget);
      expect(find.text('My followings'), findsOneWidget);
      expect(find.text('Royal Center'), findsNothing);
    },
  );

  testWidgets(
    'top tabs are tappable and PageView swipes between sections',
    (tester) async {
      final state = makeState();
      await tester.pumpWidget(TinniStarApp(state: state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-party-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('top-tab-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-events-page')), findsOneWidget);
      expect(find.text('Royal Events'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('home-top-page-view')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-country-page')), findsOneWidget);
      expect(find.text('Country Rooms'), findsOneWidget);

      await tester.tap(find.byKey(const Key('top-tab-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-mine-page')), findsOneWidget);
      expect(find.text('My room'), findsOneWidget);
    },
  );

  testWidgets('party ranking controls open destinations', (tester) async {
    final state = makeState();
    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('party-promo-carousel')), findsOneWidget);
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('CP Ranking'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-ranking-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-screen')), findsOneWidget);
  });
}
