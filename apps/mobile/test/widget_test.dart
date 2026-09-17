import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main.dart';

void main() {
  testWidgets('v0.2 demo opens upgraded 30-seat room', (tester) async {
    await tester.pumpWidget(const VoiceChatApp());

    expect(find.text('Voice Chat v0.2'), findsOneWidget);
    expect(find.text('Continue in Demo Mode'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-demo')));
    await tester.pumpAndSettle();

    expect(find.text('Discover Rooms'), findsOneWidget);
    expect(find.text('Night Vibes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-night-vibes')));
    await tester.pumpAndSettle();

    expect(find.text('Room ID 10000000 • 30 seats'), findsOneWidget);
    expect(find.text('Invite ON'), findsOneWidget);
    expect(find.byKey(const Key('seat-grid')), findsOneWidget);
    expect(find.byKey(const Key('owner-tools')), findsOneWidget);
  });
}
