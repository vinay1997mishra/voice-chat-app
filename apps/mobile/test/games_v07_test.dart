import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/games_v07.dart';

void main() {
  testWidgets('v0.7 game center exposes all six local games',(tester) async {
    tester.view.physicalSize=const Size(1080,2400);tester.view.devicePixelRatio=3;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home:GamesCenterV07()));
    for(final name in ['UNO','Ludo','Lucky Dice','Lucky Wheel','Rock Paper Scissors','Teen Patti']){
      expect(find.text(name),findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('game-v07-2')));
    await tester.pumpAndSettle();
    expect(find.text('Lucky Dice'),findsOneWidget);
    await tester.tap(find.byKey(const Key('game-play-v07')));
    await tester.pump();
    expect(find.byKey(const Key('game-result-v07')),findsOneWidget);
  });
}
