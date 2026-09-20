import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main_v05.dart';

void main() {
  testWidgets('v0.5 shows seat actions and room four-box tools', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const VoiceChatV05());

    expect(find.text('Create Room'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-room')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room-seat-grid')), findsOneWidget);
    await tester.tap(find.byKey(const Key('seat-0')));
    await tester.pumpAndSettle();
    expect(find.text('Lock Seat'), findsOneWidget);
    expect(find.text('Mute Seat'), findsOneWidget);

    await tester.tap(find.text('Lock Seat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seat-0')));
    await tester.pumpAndSettle();
    expect(find.text('Unlock Seat'), findsOneWidget);

    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('four-box-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('LP'), findsOneWidget);
    expect(find.text('Game'), findsOneWidget);
    expect(find.text('Room DP'), findsOneWidget);
  });
}
