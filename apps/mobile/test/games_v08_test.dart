import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/games_v08.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('v0.8 game center exposes seven colorful local games', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: GamesCenterV08()));
    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('UNO'), findsOneWidget);
    expect(find.text('Carrom'), findsOneWidget);
    expect(find.text('Lucky Dice'), findsOneWidget);
    expect(find.text('Lucky Wheel'), findsOneWidget);
    expect(find.text('Rock Paper Scissors'), findsOneWidget);
    expect(find.text('Teen Patti'), findsOneWidget);
  });

  testWidgets('Ludo local mode has four playable seats and 3D board', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      const MaterialApp(home: LudoGameV08(mode: V08GameMode.localMulti)),
    );
    expect(find.byKey(const Key('ludo-four-player-v08')), findsOneWidget);
    for (var i = 1; i <= 4; i++) {
      expect(find.byKey(Key('ludo-seat-' + i.toString() + '-v08')), findsOneWidget);
    }
    expect(find.byKey(const Key('ludo-board-v08')), findsOneWidget);
    expect(find.byKey(const Key('ludo-roll-v08')), findsOneWidget);
    expect(find.textContaining('4 Player 3D'), findsOneWidget);
  });

  testWidgets('UNO local mode is a real four-seat table', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      const MaterialApp(home: UnoGameV08(mode: V08GameMode.localMulti)),
    );
    expect(find.byKey(const Key('uno-four-player-v08')), findsOneWidget);
    for (var i = 1; i <= 4; i++) {
      expect(find.byKey(Key('uno-seat-' + i.toString() + '-v08')), findsOneWidget);
    }
    expect(find.byKey(const Key('uno-draw-v08')), findsOneWidget);
    expect(find.textContaining('4 Player 3D'), findsOneWidget);
  });

  testWidgets('Carrom local mode has four seats and 3D board', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      const MaterialApp(home: CarromGameV08(mode: V08GameMode.localMulti)),
    );
    expect(find.byKey(const Key('carrom-four-player-v08')), findsOneWidget);
    for (var i = 1; i <= 4; i++) {
      expect(find.byKey(Key('carrom-seat-' + i.toString() + '-v08')), findsOneWidget);
    }
    expect(find.byKey(const Key('carrom-board-v08')), findsOneWidget);
    expect(find.textContaining('4 Player 3D'), findsOneWidget);
  });

  testWidgets('bot launcher keeps four-seat mode descriptions', (tester) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: GameLauncherV08(game: 'UNO')));
    expect(find.text('Solo vs Bot'), findsOneWidget);
    expect(find.textContaining('3 bots'), findsOneWidget);
    expect(find.text('Local Multiplayer'), findsOneWidget);
    expect(find.textContaining('4 seats'), findsOneWidget);
  });
}
