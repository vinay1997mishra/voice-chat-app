import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main_v07.dart';

void main() {
  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('final v0.7 includes shell wallet and room tools', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV07());

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
    expect(find.text('Wallet'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-v07-room')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v07-seat-grid')), findsOneWidget);
    await tester.tap(find.byKey(const Key('v07-seat-0')));
    await tester.pumpAndSettle();
    expect(find.text('Lock Seat'), findsOneWidget);
    expect(find.text('Mute Seat'), findsOneWidget);
    Navigator.of(tester.element(find.text('Lock Seat'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v07-four-box')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v07-tools-grid')), findsOneWidget);
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

  testWidgets('gift goes to recipient ID and appears in inbox and wallet', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(const VoiceChatV07());

    await tester.tap(find.byKey(const Key('open-v07-room')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gift'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gift-recipient-v06')), findsOneWidget);
    expect(find.text('Owner • ID 10000000'), findsOneWidget);
    expect(find.text('Rose'), findsOneWidget);
    expect(find.text('Dragon'), findsOneWidget);
    expect(find.text('Galaxy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gift-rose-v06')));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.text('Gift sent to ID 10000000'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Transaction History'), findsOneWidget);
    expect(find.text('Gift sent: Rose'), findsOneWidget);
    expect(find.text('Diamond → Coins'), findsOneWidget);
  });
}
