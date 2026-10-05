
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/ui/rocket_rewards_panel.dart';

void main() {
  testWidgets('only three ranking boxes show linear coins, medals and frames', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RocketRewardsPanel(level: 6, data: {
      'top': [
        {'name':'First sender','coins':2400000,'frame_id':'rocket-l6-top1','awarded':true},
        {'name':'Second sender','coins':1200000,'frame_id':'rocket-l6-top2','awarded':true},
        {'name':'Third sender','coins':600000,'frame_id':'rocket-l6-top3','awarded':true},
      ],
    }))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('24 L coins'), findsOneWidget);
    expect(find.text('12 L coins'), findsOneWidget);
    expect(find.text('6 L coins'), findsOneWidget);
    expect(find.text('Rocket 6'), findsNWidgets(3));
    expect(find.text('Received'), findsNWidgets(3));
    expect(find.byKey(const Key('rocket-top-4-reward')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
