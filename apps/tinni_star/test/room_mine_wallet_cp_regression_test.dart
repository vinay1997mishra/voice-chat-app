import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room tags stay off seats and render only with comments', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(room.contains('seat-owner-tag-'), false);
    expect(room.contains('seat-owner-medal-'), false);
    expect(room.contains('room-live-owner-badges'), false);
    expect(room.contains('room-comment-tag-'), true);
    expect(room.contains("label: 'Host'"), false);
    expect(room.contains("label: 'Agency'"), false);
    expect(room.contains('_roomMessageScrollController'), true);
    expect(room.contains('position.maxScrollExtent'), true);
    expect(room.contains('fontSize: 11.5'), true);

    final session =
        File('lib/room/active_room_session.dart').readAsStringSync();
    expect(session.contains('_syncRoomJoinMessages'), true);
    expect(session.contains("'entered the room'"), true);

    final presenceWorker =
        File('../tinni_worker/src/room_presence.js').readAsStringSync();
    final workerIndex =
        File('../tinni_worker/src/index.js').readAsStringSync();
    expect(presenceWorker.contains('designation:'), true);
    expect(presenceWorker.contains('background_color:'), true);
    expect(workerIndex.contains('listUserIdentityTags(user.user_id)'), true);
  });

  test('Mine hierarchy panel order is BD Agency Host', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final bd = profile.indexOf("mine-bd-panel");
    final agency = profile.indexOf("mine-agency-panel");
    final host = profile.indexOf("mine-host-panel");

    expect(bd, greaterThanOrEqualTo(0));
    expect(agency, greaterThan(bd));
    expect(host, greaterThan(agency));
    expect(profile.contains('widget.state.wallet.isAgency'), true);
  });

  test('Coin Seller uses only a four digit numeric PIN', () {
    final recharge =
        File('lib/screens/recharge_screen.dart').readAsStringSync();
    final worker =
        File('../tinni_worker/src/app_directory.js').readAsStringSync();

    expect(recharge.contains('password.length == 4'), true);
    expect(
      recharge.contains('FilteringTextInputFormatter.digitsOnly'),
      true,
    );
    expect(recharge.contains('maxLength: _isCoinSellerPin(walletType) ? 4'), true);
    expect(
      worker.contains('Coin Seller wallet PIN must be exactly 4 digits'),
      true,
    );
  });

  test('room lock is generated and owner can unlock without password', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final worker =
        File('../tinni_worker/src/app_directory.js').readAsStringSync();

    expect(room.contains('_promptNewRoomPassword'), false);
    expect(room.contains('lastGeneratedRoomPassword'), true);
    expect(room.contains("'Locked • Password '"), true);
    expect(worker.contains('display_password TEXT'), true);
    expect(worker.contains('10000 + (randomValue % 90000)'), true);
    expect(worker.contains('owner_bypass: true'), true);
  });

  test('Public Screen menu is moderator-only and can clear comments', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final controller =
        File('lib/room/room_controller.dart').readAsStringSync();
    final controls =
        File('lib/room/room_control_service.dart').readAsStringSync();
    final presence =
        File('lib/room/room_presence_service.dart').readAsStringSync();
    final session =
        File('lib/room/active_room_session.dart').readAsStringSync();
    final workerIndex =
        File('../tinni_worker/src/index.js').readAsStringSync();
    final presenceWorker =
        File('../tinni_worker/src/room_presence.js').readAsStringSync();

    expect(room.contains("title: const Text('Only Admin/Owner can type')"), true);
    expect(room.contains("title: const Text('Everyone can type')"), true);
    expect(room.contains("title: const Text('Clear comments area')"), true);
    expect(room.contains("key: const Key('public-screen-clear-comments')"), true);
    expect(room.contains("if (!_canModerateSeats && label == 'Public Screen')"), true);
    expect(room.contains('roomSession.clearRoomComments()'), true);
    expect(room.contains('presence.commentsClearVersion'), true);
    expect(room.contains('presence.ownerCommentsClearVersion'), true);
    expect(room.contains('isOwnerForCommentClear'), true);
    expect(controller.contains('void clearRoomMessages()'), true);
    expect(controller.contains('messages.clear();'), true);
    expect(controls.contains('setPublicScreenEnabled(bool enabled)'), true);
    expect(presence.contains("'/room-presence/public-screen'"), true);
    expect(presence.contains("'/room-presence/clear-comments'"), true);
    expect(presence.contains('ownerCommentsClearVersion'), true);
    expect(presence.contains("type': 'chat_message'"), true);
    expect(session.contains('Future<void> setRoomPublicScreen(bool enabled)'), true);
    expect(session.contains('Future<void> clearRoomComments()'), true);
    expect(session.contains('Future<void> sendRoomComment(String text)'), true);
    expect(session.contains('_syncRoomChatMessages()'), true);
    expect(workerIndex.contains('"/room-presence/public-screen"'), true);
    expect(workerIndex.contains('"/room-presence/clear-comments"'), true);
    expect(workerIndex.contains('store.clearComments(actorId, actorIsOwner)'), true);
    expect(presenceWorker.contains('public_screen_enabled'), true);
    expect(presenceWorker.contains('comments_clear_version'), true);
    expect(presenceWorker.contains('owner_comments_clear_version'), true);
    expect(presenceWorker.contains('clear_scope: ownerClear ? "all" : "non_owner"'), true);
    expect(presenceWorker.contains('payload?.type === "chat_message"'), true);
    expect(presenceWorker.contains('_broadcastRoomEvent({'), true);
  });

  test('new room entrants receive only post-join live comments', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final presence =
        File('lib/room/room_presence_service.dart').readAsStringSync();
    final session =
        File('lib/room/active_room_session.dart').readAsStringSync();
    final presenceWorker =
        File('../tinni_worker/src/room_presence.js').readAsStringSync();

    expect(room.contains('roomSession.sendRoomComment('), true);
    expect(room.contains('controller.sendMessage(value);'), false);
    expect(presence.contains('RoomChatEvent? latestChatEvent;'), true);
    expect(session.contains('_seenRoomChatEventIds'), true);
    expect(session.contains('presence.latestChatEvent'), true);
    expect(presenceWorker.contains('type: "chat_message"'), true);
    expect(presenceWorker.contains('chat_history'), false);
  });

  test('empty seat invite is locked to in-room off-seat IDs', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final presence =
        File('lib/room/room_presence_service.dart').readAsStringSync();
    final session =
        File('lib/room/active_room_session.dart').readAsStringSync();
    final presenceWorker =
        File('../tinni_worker/src/room_presence.js').readAsStringSync();
    final blueprint =
        File('../../docs/TINNI_STAR_COMPLETE_IMPLEMENTATION_BLUEPRINT_V3.md')
            .readAsStringSync();
    final changeLock =
        File('../../docs/TINNI_STAR_GLOBAL_CHANGE_LOCK.md').readAsStringSync();

    expect(room.contains("key: const Key('seat-control-invite')"), true);
    expect(room.contains('Future<void> _showSeatInvitePanel(int seatIndex)'), true);
    expect(room.contains("key: const Key('seat-invite-id-search')"), true);
    expect(room.contains('member.seatIndex == null'), true);
    expect(room.contains('member.userId != currentUserId'), true);
    expect(room.contains('member.userId.toLowerCase().contains(normalizedQuery)'), true);
    expect(room.contains('seatIndex: seatIndex'), true);
    expect(room.contains("' invites you to Seat No. '"), true);
    expect(session.contains('inviteUserToSeat('), true);
    expect(presenceWorker.contains('User is not in the room'), true);
    expect(presenceWorker.contains('User is already on a seat'), true);
    expect(presenceWorker.contains('Seat is already occupied'), true);
    expect(presenceWorker.contains('You cannot invite yourself to a seat'), true);
    expect(
      presenceWorker.contains('Seat is outside the current room seat range'),
      true,
    );
    expect(
      presenceWorker.contains('_broadcastPresence("seat_invite_changed", now)'),
      true,
    );
    expect(presenceWorker.contains('User is no longer in the room'), true);
    expect(
      presenceWorker.contains('Invited seat is no longer available'),
      true,
    );
    expect(
      presence.contains('pendingSeatInvite?.createdAt.millisecondsSinceEpoch'),
      true,
    );
    expect(blueprint.contains('## Empty-Seat Invite Flow — LOCKED'), true);
    expect(changeLock.contains('Empty-seat invite lock:'), true);
  });

  test('room backend stays active even when voice is unavailable', () {
    final session =
        File('lib/room/active_room_session.dart').readAsStringSync();
    final room = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(session.contains('_activeAuthToken = authToken;'), true);
    expect(session.contains('final presenceStart = _startPresence();'), true);
    expect(session.contains('await presenceStart;'), true);
    expect(
      session.contains(
        'Allow microphone access to use voice.',
      ),
      true,
    );
    expect(
      session.contains('Voice connection failed: '),
      true,
    );
    expect(session.contains('bool get backendSessionActive'), true);
    expect(
      room.contains(
        "session.room?.id != widget.room.id || !session.backendSessionActive",
      ),
      true,
    );
  });

  test('all built-in mood room themes are backend accepted', () {
    final controls =
        File('lib/room/room_control_service.dart').readAsStringSync();
    final worker =
        File('../tinni_worker/src/app_directory.js').readAsStringSync();

    for (final id in <String>[
      'royal-dark',
      'night-blue',
      'rose-gold',
      'mood-happy',
      'mood-sad',
      'mood-boring',
      'mood-love',
      'mood-mountain-view',
      'mood-alone',
      'mood-with-her',
      'mood-with-him',
      'mood-love-scene',
      'mood-rainy-love',
    ]) {
      expect(controls.contains("'$id'"), true);
      expect(worker.contains('"$id"'), true);
    }
  });

  test('room action errors remain readable during recovery', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(room.contains('duration: const Duration(seconds: 5)'), true);
    expect(room.contains('messenger.hideCurrentSnackBar();'), true);
  });

  test('seat area never extends below the 42-seat lower boundary', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(room.contains('final reference42SeatSpec = SeatLayoutSpec.forCount(42);'), true);
    expect(room.contains('reference42SeatAreaHeight'), true);
    expect(room.contains('math.min(maxSeatAreaHeight, reference42SeatAreaHeight)'), true);
  });

  test('CP economy and profile card stay scaled to Tinni', () {
    final cp = File('lib/screens/cp_screen.dart').readAsStringSync();
    final profile =
        File('lib/screens/public_profile_screen.dart').readAsStringSync();
    final worker =
        File('../tinni_worker/src/app_directory.js').readAsStringSync();

    final gifts = File('lib/economy/premium_gift_catalog.dart').readAsStringSync();
    expect(gifts.contains('id: "cp-heart"'), true);
    expect(gifts.contains('price: 44444'), true);
    expect(gifts.contains('id: "cp-invite"'), true);
    expect(gifts.contains('price: 2222222'), true);
    expect(profile.contains("Key('profile-cp-card')"), true);
    expect(cp.contains('2,222,222 Tinni coins'), true);
    expect(cp.contains('5% per day'), true);
    expect(worker.contains('reference_coins_per_usd: 45000'), true);
    expect(worker.contains('tinni_coins_per_usd: 2000000'), true);
    expect(worker.contains('lucky_gift_intimacy_percent: 10'), true);
    expect(worker.contains('Math.floor(intimacy * 95 / 100)'), true);
  });
}
