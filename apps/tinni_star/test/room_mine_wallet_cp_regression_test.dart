import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room tags stay off seats and render only with comments', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(room.contains('seat-owner-tag-'), false);
    expect(room.contains('seat-owner-medal-'), false);
    expect(room.contains('room-live-owner-badges'), false);
    expect(room.contains('room-comment-tag-'), true);
    expect(room.contains('_roomMessageScrollController'), true);
    expect(room.contains('position.maxScrollExtent'), true);
    expect(room.contains('fontSize: 10.5'), true);
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
