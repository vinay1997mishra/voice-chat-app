import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/ui/premium_effects.dart';

void main() {
  test('premium pack exposes ten of each effect type', () {
    expect(PremiumEffectStyle.frameIds.length, 10);
    expect(PremiumEffectStyle.profileCardIds.length, 10);
    expect(PremiumEffectStyle.entryIds.length, 10);
    expect(
      <String>{
        ...PremiumEffectStyle.frameIds,
        ...PremiumEffectStyle.profileCardIds,
        ...PremiumEffectStyle.entryIds,
      }.length,
      30,
    );
  });

  testWidgets('premium entrance renders and completes', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumEntranceOverlay(
            entryId: 'entry-phoenix-fire',
            displayName: 'Tinni',
            onFinished: () => finished = true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('premium-entrance-entry-phoenix-fire')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3500));
    expect(finished, isTrue);
  });
}
