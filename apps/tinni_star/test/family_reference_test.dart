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

    // Ranking rows come only from the live backend. Widget tests run with
    // HttpClient blocked, so they must not rely on fake hard-coded Families.
    expect(find.text('No Families have been created yet.'), findsOneWidget);
  });
}
