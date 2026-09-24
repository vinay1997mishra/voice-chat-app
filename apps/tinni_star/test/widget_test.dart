import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';

import 'test_account.dart';

void main() {
  testWidgets('Tinni Star renders Google login then authenticated home shell',
      (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pump();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Login with Email / Gmail'), findsOneWidget);
    expect(find.text('Continue with Phone'), findsNothing);

    attachTestAccount(state);
    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-party-page')), findsOneWidget);
    expect(find.byKey(const Key('home-ranking-button')), findsOneWidget);
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('CP Ranking'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
  });
}
