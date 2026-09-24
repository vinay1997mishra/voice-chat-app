import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/screens/family_ranking_screen.dart';

import 'test_account.dart';

void main() {
  TinniState makeState() {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    attachTestAccount(state);
    return state;
  }

  testWidgets('family ranking follows reference flow', (tester) async {
    final state = makeState();
    await tester.pumpWidget(
      MaterialApp(home: FamilyRankingScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top Families of the Month'), findsOneWidget);
    expect(find.byKey(const Key('family-ranking-list')), findsOneWidget);
    expect(find.byKey(const Key('family-create-button')), findsOneWidget);
    expect(find.byKey(const Key('family-ranking-join-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('family-rank-row-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('family-home-screen')), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Trends'), findsOneWidget);
    expect(find.text('Top members of the family'), findsOneWidget);
    expect(find.text('Member list'), findsOneWidget);
  });
}
