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

    expect(room.contains("title: const Text('Only Admin/Owner can type')"), true);
    expect(room.contains("title: const Text('Everyone can type')"), true);
    expect(room.contains("title: const Text('Clear comments area')"), true);
    expect(room.contains("key: const Key('public-screen-clear-comments')"), true);
    expect(room.contains("if (!_canModerateSeats && label == 'Public Screen')"), true);
    expect(room.contains('controller.clearRoomMessages();'), true);
    expect(controller.contains('void clearRoomMessages()'), true);
    expect(controller.contains('messages.clear();'), true);
    expect(controls.contains('setPublicScreenEnabled(bool enabled)'), true);
  });

  test('room action notification lasts one second', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(room.contains('duration: const Duration(seconds: 1)'), true);
    expect(room.contains('messenger.hideCurrentSnackBar();'), true);
  });

  test('seat area never extends below the 42-seat lower boundary', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(room.contains('final reference42SeatSpec = SeatLayoutSpec.forCount(42);'), true);
    expect(room.contains('reference42SeatAreaHeight'), true);
    expect(room.contains('math.min(maxSeatAreaHeight, reference42SeatAreaHeight)'), true);
  });

  test('CP economy and profile card stay scaled to Tinni', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final cp = File('lib/screens/cp_screen.dart').readAsStringSync();
    final profile =
        File('lib/screens/public_profile_screen.dart').readAsStringSync();
    final worker =
        File('../tinni_worker/src/app_directory.js').readAsStringSync();

    expect(room.contains("id: 'cp-heart'"), true);
    expect(room.contains('price: 44444'), true);
    expect(room.contains("id: 'cp-invite'"), true);
    expect(room.contains('price: 2222222'), true);
    expect(profile.contains("Key('profile-cp-card')"), true);
    expect(cp.contains('2,222,222 Tinni coins'), true);
    expect(cp.contains('5% per day'), true);
    expect(worker.contains('reference_coins_per_usd: 45000'), true);
    expect(worker.contains('tinni_coins_per_usd: 2000000'), true);
    expect(worker.contains('lucky_gift_intimacy_percent: 10'), true);
    expect(worker.contains('Math.floor(intimacy * 95 / 100)'), true);
  });
}
