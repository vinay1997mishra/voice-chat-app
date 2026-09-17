import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main_v03.dart';

void main() {
  testWidgets('v0.3 opens room and feature hubs', (tester) async {
    await tester.pumpWidget(const VoiceChatV03App());

    expect(find.text('Voice Chat v0.3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue-v03')));
    await tester.pumpAndSettle();

    expect(find.text('Discover Rooms'), findsOneWidget);
    expect(find.text('VIP Center'), findsOneWidget);
    expect(find.text('Lucky Bag'), findsOneWidget);
    expect(find.text('Game Center'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-v03-room')));
    await tester.pumpAndSettle();

    expect(find.text('Room ID 10000000 • 30 seats'), findsOneWidget);
    expect(find.byKey(const Key('seat-grid-v03')), findsOneWidget);
    expect(find.byKey(const Key('owner-tools-v03')), findsOneWidget);
  });
}
