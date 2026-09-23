import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';

void main() {
  testWidgets('Tinni Star login opens room and renders seat grid', (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
    );
    await tester.pumpWidget(TinniStarApp(state: state));

    await tester.tap(find.text('Continue with Phone'));
    await tester.pumpAndSettle();
    expect(find.text('India Official Room'), findsOneWidget);

    final roomCard = find.byKey(const Key('room-card-1524843'));
    await tester.ensureVisible(roomCard);
    await tester.pumpAndSettle();
    await tester.tap(roomCard);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);

    await tester.tap(find.byTooltip('Minimize room'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mini-room-bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mini-room-bar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tinni-seat-grid')), findsOneWidget);
  });
}
