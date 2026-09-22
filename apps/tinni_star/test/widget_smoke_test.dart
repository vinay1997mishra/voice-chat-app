import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';

void main() {
  testWidgets('Tinni Star shell opens room and renders seat grid', (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    await tester.pumpWidget(TinniStarApp(state: state));
    expect(find.text('Tinni Star ✨'), findsOneWidget);
    expect(find.text('India Official Room'), findsOneWidget);

    await tester.tap(find.text('India Official Room').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);
  });
}
