import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';

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

  testWidgets(
    'top Mine is room-focused and separate from bottom profile Mine',
    (tester) async {
      final state = makeState();
      state.discovery.createRoom(title: 'My Test Room', country: 'IN');
      state.discovery.visit('10000003');
      state.discovery.toggleFavorite('10000004');

      await tester.pumpWidget(TinniStarApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('top-tab-0')));
      await tester.pumpAndSettle();

      expect(find.text('My room'), findsOneWidget);
      expect(find.text('My Test Room'), findsOneWidget);
      expect(find.text('Recents'), findsOneWidget);
      expect(find.text('My followings'), findsOneWidget);
      final minePage = find.byKey(const Key('home-mine-page'));
      await tester.drag(minePage, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(find.text('Night Kings'), findsOneWidget);
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
      expect(find.text('Recents'), findsOneWidget);
      expect(find.text('My followings'), findsOneWidget);
    },
  );

  testWidgets('party ranking controls open real destinations', (tester) async {
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
    expect(find.text('Send gifts'), findsOneWidget);
    expect(find.text('Charm'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('party-room-rank-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ranking-screen')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('party-cp-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cp-ranking-screen')), findsOneWidget);
    expect(find.text('Ranking List'), findsOneWidget);
    expect(find.text('True Love Challenge'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('party-family-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-ranking-screen')), findsOneWidget);
    expect(find.text('Family Ranking'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsWidgets);
  });
}
