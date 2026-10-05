import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/ui/rocket_rewards_panel.dart';

void main() {
  testWidgets('ranking never exposes another user received reward', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: RocketRewardsPanel(level: 6, data: {
        'top': [
          {'name':'First sender','coins':2400000,'frame_id':'rocket-l6-top1','awarded':true},
          {'name':'Second sender','coins':1200000,'frame_id':'rocket-l6-top2','awarded':true},
          {'name':'Third sender','coins':600000,'frame_id':'rocket-l6-top3','awarded':true},
        ],
      }),
    )));
    expect(find.text('First sender'), findsOneWidget);
    expect(find.text('Second sender'), findsOneWidget);
    expect(find.text('Third sender'), findsOneWidget);
    expect(find.textContaining('coins'), findsNothing);
    expect(find.text('Received'), findsNothing);
    expect(find.textContaining('medal'), findsNothing);
    expect(find.byKey(const Key('rocket-top-4-reward')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
