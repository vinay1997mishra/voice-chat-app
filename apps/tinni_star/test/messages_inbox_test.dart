import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/screens/feature_center_screen.dart';
import 'package:tinni_star/screens/messages_screen.dart';
import 'package:tinni_star/social/social.dart';

import 'test_account.dart';

TinniState makeState() {
  final state = TinniState(
    runtime: FunctionPackRuntime(
      signatureVerifier: const DevelopmentSignatureVerifier(),
    ),
  );
  attachTestAccount(state);
  return state;
}

void main() {
  testWidgets('bottom Message tab opens inbox with random call header',
      (tester) async {
    final state = makeState();
    state.social.messageThreads.add(
      const MessageThread(
        userId: 'friend-1',
        displayName: 'Friend One',
        isFriend: true,
        unreadCount: 2,
        lastMessage: ChatMessage(
          id: 'm1',
          from: 'friend-1',
          to: '91000001',
          text: 'Hello',
        ),
      ),
    );
    state.social.friends.add('friend-1');

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pump();

    await tester.tap(find.text('Message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('messages-inbox')), findsOneWidget);
    expect(find.byKey(const Key('message-thread-friend-1')), findsOneWidget);
    expect(
      find.byKey(const Key('messages-random-call-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('message-call-friend-1')), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('conversation shows Sent Seen and call in message header',
      (tester) async {
    final state = makeState();
    state.social.friends.add('friend-1');
    state.social.friendProfiles.add(
      const SocialUser(id: 'friend-1', name: 'Friend One'),
    );
    state.social.directMessages.addAll([
      const ChatMessage(
        id: 'sent-1',
        from: '91000001',
        to: 'friend-1',
        text: 'First',
      ),
      ChatMessage(
        id: 'seen-1',
        from: '91000001',
        to: 'friend-1',
        text: 'Second',
        seenAt: DateTime(2026, 9, 26),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          state: state,
          targetUserId: 'friend-1',
          targetName: 'Friend One',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('message-conversation')), findsOneWidget);
    expect(find.byKey(const Key('message-conversation-call')), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Seen'), findsOneWidget);
    expect(find.byKey(const Key('message-input')), findsOneWidget);
    expect(find.byKey(const Key('message-send-button')), findsOneWidget);
  });

  testWidgets('Official paid call notice shows verification action',
      (tester) async {
    final state = makeState();
    state.social.directMessages.add(
      const ChatMessage(
        id: 'official-call-1',
        from: 'tinni-official',
        to: '91000001',
        text:
            '[CALL_VERIFY] Incoming friend paid call. Your ID is Unverified.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          state: state,
          targetUserId: 'tinni-official',
          targetName: 'Tinni Official',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const Key('official-call-verify-official-call-1')),
      findsOneWidget,
    );
    expect(find.text('Verify Call ID'), findsOneWidget);
  });

  testWidgets('Calls tile is removed from More', (tester) async {
    final state = makeState();
    await tester.pumpWidget(
      MaterialApp(home: FeatureCenterScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calls'), findsNothing);
  });
}
