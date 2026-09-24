import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';

void main() {
  testWidgets('create room modal closes cleanly and opens created room',
      (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    state.auth.loginDemo();

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('top-tab-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mine-create-my-room')));
    await tester.pumpAndSettle();

    expect(find.text('Create room'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('create-room-name')),
      'My Safe Room',
    );
    final submit = find.byKey(const Key('create-room-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);

    // Finish modal removal + deferred room route push.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      state.discovery.rooms.any((room) => room.title == 'My Safe Room'),
      true,
    );
    expect(find.text('My Safe Room'), findsWidgets);
    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
