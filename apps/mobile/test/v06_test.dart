import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main_v06.dart';

void main() {
  testWidgets('final v0.6 includes v0.5 shell, wallet and v0.6 room controls', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VoiceChatV06());

    expect(find.byKey(const Key('create-room-v06')), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('Coins'), findsOneWidget);
    expect(find.text('Diamond'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-v06-room')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v06-seat-grid')), findsOneWidget);

    await tester.tap(find.byKey(const Key('v06-seat-0')));
    await tester.pumpAndSettle();
    expect(find.text('Lock Seat'), findsOneWidget);
    expect(find.text('Mute Seat'), findsOneWidget);
    Navigator.of(tester.element(find.text('Lock Seat'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v06-four-box')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v06-tools-grid')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('LP'), findsOneWidget);
    expect(find.text('Game'), findsOneWidget);
    expect(find.text('Room DP'), findsOneWidget);
    expect(find.text('Background'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Admins'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
  });
}
