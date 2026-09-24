import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';

void main() {
  testWidgets('Tinni Star renders login then home shell', (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    await tester.pumpWidget(TinniStarApp(state: state));

    expect(find.text('Continue with Phone'), findsOneWidget);
    await tester.tap(find.text('Continue with Phone'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-party-page')), findsOneWidget);
    expect(find.byKey(const Key('home-ranking-button')), findsOneWidget);
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('CP Ranking'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
  });
}
