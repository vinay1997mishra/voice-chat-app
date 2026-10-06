import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/app/tinni_app.dart';
import 'package:tinni_star/app/tinni_state.dart';
import 'package:tinni_star/core/function_pack.dart';
import 'package:tinni_star/discovery/discovery_service.dart';
import 'package:tinni_star/identity/owner_tag.dart';
import 'package:tinni_star/room/room_presence_service.dart';
import 'package:tinni_star/ui/stable_image_provider.dart';

import 'test_account.dart';

const _pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  testWidgets(
      'room DPs tags and profile taps follow IDs despite duplicate or reserved names',
      (tester) async {
    final state = TinniState(
      runtime: FunctionPackRuntime(
        signatureVerifier: const DevelopmentSignatureVerifier(),
      ),
      roomPresenceFallbackTimerEnabled: false,
    );
    final account = attachTestAccount(state, avatarDataUrl: _pixel);
    final now = DateTime.now();
    state.roomPresence.members.addAll([
      RoomPresenceMember(
        userId: '92000002',
        displayName: 'Duplicate',
        joinedAt: now,
        lastSeen: now,
        ownerTags: const [OwnerTag(name: 'First Host', colorHex: '#FF4081')],
      ),
      RoomPresenceMember(
        userId: '92000003',
        displayName: 'Duplicate',
        avatarDataUrl: _pixel,
        joinedAt: now,
        lastSeen: now,
        ownerTags: const [OwnerTag(name: 'Second Host', colorHex: '#4FC3F7')],
      ),
    ]);
    state.discovery.rooms.add(RoomSummary(
      id: account.userId,
      title: 'Identity Room',
      country: account.countryCode,
      countryName: account.countryName,
      flagEmoji: account.flagEmoji,
      online: 2,
      seatCount: 12,
      createdAt: now,
      ownerId: account.userId,
      ownerName: account.displayName,
      ownerFlagEmoji: account.flagEmoji,
    ));

    await tester.pumpWidget(TinniStarApp(state: state));
    await tester.pumpAndSettle();
    final roomCard = find.byKey(Key('room-card-${account.userId}'));
    await tester.ensureVisible(roomCard);
    await tester.tap(roomCard);
    await tester.pumpAndSettle();

    final controller = state.roomSession.controller!;
    Future<void> showMessage(String author, String text, {String? userId}) async {
      controller.clearRoomMessages();
      controller.addRoomMessage(author, text, userId: userId);
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
    }
    CircleAvatar avatar(String key) =>
        tester.widget<CircleAvatar>(find.byKey(Key(key)));

    await showMessage('Previous name', 'First sender', userId: '92000002');
    expect(avatar('room-comment-dp-92000002').backgroundImage, isNull);
    expect(find.byKey(const Key('room-comment-tag-92000002-First Host')),
        findsOneWidget);
    expect(find.byKey(const Key('room-comment-tag-92000003-Second Host')),
        findsNothing);

    await showMessage('Duplicate', 'Second sender', userId: '92000003');
    expect(avatar('room-comment-dp-92000003').backgroundImage,
        same(stableImageProvider(_pixel)));
    expect(find.byKey(const Key('room-comment-tag-92000003-Second Host')),
        findsOneWidget);
    expect(find.byKey(const Key('room-comment-tag-92000002-First Host')),
        findsNothing);
    final secondDp = find.byKey(const Key('room-comment-dp-92000003'));
    await tester.ensureVisible(secondDp);
    await tester.tap(secondDp);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-user-profile-card-92000003')),
        findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await showMessage('Duplicate', 'No sender ID');
    expect(avatar('room-comment-dp-Duplicate').backgroundImage, isNull);
    expect(find.byKey(const Key('room-comment-tag-92000002-First Host')),
        findsNothing);
    expect(find.byKey(const Key('room-comment-tag-92000003-Second Host')),
        findsNothing);
    final unknownDp = find.byKey(const Key('room-comment-dp-Duplicate'));
    await tester.ensureVisible(unknownDp);
    await tester.tap(unknownDp);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-user-profile-card-92000002')),
        findsNothing);
    expect(find.byKey(const Key('room-user-profile-card-92000003')),
        findsNothing);

    await showMessage('You', 'Departed sender', userId: '92000004');
    expect(avatar('room-comment-dp-92000004').backgroundImage, isNull);
    final departedDp = find.byKey(const Key('room-comment-dp-92000004'));
    await tester.ensureVisible(departedDp);
    await tester.tap(departedDp);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-user-profile-92000004')),
        findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await showMessage(account.displayName, 'My message', userId: account.userId);
    expect(avatar('room-comment-dp-${account.userId}').backgroundImage,
        same(stableImageProvider(_pixel)));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
