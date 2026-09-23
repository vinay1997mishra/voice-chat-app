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

  testWidgets('party buttons open real destinations', (tester) async {
    final state = makeState();
    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('party-game-button')));
    await tester.pumpAndSettle();
    expect(find.text('Game Center'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsWidgets);
  });
}
