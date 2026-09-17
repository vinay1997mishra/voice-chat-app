import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_chat_app/main_v04.dart';

void main() {
  testWidgets('v0.4 uses Home Discover Message Me and royal room controls', (tester) async {
    await tester.pumpWidget(const VoiceChatV04());

    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('India Official Room'), findsOneWidget);
    expect(find.text('Wallet'), findsNothing);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('me-screen')), findsOneWidget);
    expect(find.text('Coins'), findsOneWidget);
    expect(find.text('Diamond'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('official-room-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room-seat-grid')), findsOneWidget);
    expect(find.byKey(const Key('room-bottom-tools')), findsOneWidget);
    expect(find.text('Seat Lock'), findsOneWidget);
    expect(find.text('Go to Seat'), findsOneWidget);
    expect(find.text('Room Settings'), findsOneWidget);
  });
}
