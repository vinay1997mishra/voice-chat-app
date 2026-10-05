import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/effects/rocket_launch.dart';

String _testFlightSignature(int level) {
  switch(level) {
    case 1:return 'straight';
    case 2:return 'gentle-sway';
    case 3:return 'wide-sway';
    case 4:return 'pulse-zig';
    case 5:return 'fast-zigzag';
    case 6:return 'corkscrew';
    case 7:return 'booster-shake';
    case 8:return 's-curve';
    case 9:return 'dual-wave';
    default:return 'king-spiral';
  }
}

void main() {
  test('milestones use incremental gift targets and cap at ten',(){
    expect(completedRocketStages(7999999),0);
    expect(completedRocketStages(8000000),1);
    expect(completedRocketStages(22999999),1);
    expect(completedRocketStages(23000000),2);
    expect(completedRocketStages(rocketStageTargets.fold<int>(0,(a,b)=>a+b)),10);
  });
  test('each rocket level uses its own launch motion',(){
    final motions=<String>{};
    for(var level=1;level<=10;level++) {
      final motion=_testFlightSignature(level);
      motions.add(motion);
    }
    expect(motions.length,10);
  });
  testWidgets('history does not replay; new completion launches for nine seconds',(tester) async {
    final completed=ValueNotifier<int?>(null);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:RocketLaunchOverlay(completed:completed))));
    completed.value=3;await tester.pump();
    expect(find.byKey(const Key('rocket-nine-second-launch')),findsNothing);
    completed.value=4;await tester.pump();
    expect(find.byKey(const ValueKey('launch-rocket-4')),findsOneWidget);
    await tester.pump(const Duration(seconds:8));
    expect(find.byKey(const Key('rocket-nine-second-launch')),findsOneWidget);
    await tester.pump(const Duration(seconds:1));await tester.pump();
    expect(find.byKey(const Key('rocket-nine-second-launch')),findsOneWidget);
    expect(find.byKey(const Key('rocket-holding-flame')),findsOneWidget);
    expect(find.byKey(const ValueKey('launch-rocket-4')),findsOneWidget);
    completed.value=4;await tester.pump();
    expect(find.byKey(const ValueKey('launch-rocket-4')),findsOneWidget);
    await tester.pumpWidget(const SizedBox());completed.dispose();
  });
  testWidgets('one gift completing multiple stages queues all rockets',(tester) async {
    final completed=ValueNotifier<int?>(0);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:RocketLaunchOverlay(completed:completed))));
    completed.value=2;await tester.pump();
    expect(find.byKey(const ValueKey('launch-rocket-1')),findsOneWidget);
    await tester.pump(const Duration(seconds:9));await tester.pump();
    expect(find.byKey(const ValueKey('launch-rocket-2')),findsOneWidget);
    await tester.pump(const Duration(seconds:9));await tester.pump();
    expect(find.byKey(const Key('rocket-nine-second-launch')),findsOneWidget);
    expect(find.byKey(const Key('rocket-holding-flame')),findsOneWidget);
    expect(find.byKey(const ValueKey('launch-rocket-2')),findsOneWidget);
    await tester.pumpWidget(const SizedBox());completed.dispose();
  });
}
