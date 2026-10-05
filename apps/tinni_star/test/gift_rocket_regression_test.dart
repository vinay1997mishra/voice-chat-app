import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gift economy keeps Lucky at 10 percent and diamonds Host-only', () {
    final directory =
        File('../tinni_worker/src/app_directory.js').readAsStringSync();
    final index = File('../tinni_worker/src/index.js').readAsStringSync();

    expect(
      directory.contains('const socialValuePercent = isLucky ? 10 : 100;'),
      true,
    );
    expect(
      directory.contains(
        'const receiverDiamonds = receiverIsHost ? socialValueCoins : 0;',
      ),
      true,
    );
    expect(directory.contains('this._isActiveHost(receiverId)'), true);
    expect(
      directory.contains(
        'SUM(COALESCE(l.social_value_coins, g.total_cost)) AS sending',
      ),
      true,
    );
    expect(
      directory.contains(
        'COALESCE(SUM(COALESCE(l.social_value_coins, g.total_cost)), 0)',
      ),
      true,
    );
    expect(index.contains('tx?.ranking_value ??'), true);
    expect(index.contains('tx?.social_value_coins ??'), true);
  });

  test('gift flies from screen center to selected seat', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(room.contains('_giftFlightOriginOffset(BuildContext context)'), true);
    expect(
      room.contains(
        'final screenCenterGlobal = Offset(screen.width / 2, screen.height / 2);',
      ),
      true,
    );
    expect(room.contains('origin.dx * (1 - value)'), true);
    expect(room.contains('origin.dy * (1 - value) - rise'), true);
    expect(room.contains('origin.dy * (1 - value) - arc'), true);
    expect(room.contains('(1 - value) * seatDiameter * 2.35'), false);
    expect(room.contains('(1 - value) * seatDiameter * 2.8'), false);
  });

  test('approved Rocket and Game logos stay locked', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(room.contains("Key('realistic-black-rocket-logo')"), true);
    expect(room.contains('class _StealthRocketPainter'), true);
    expect(room.contains("Key('game-keyboard-logo')"), true);
    expect(room.contains('whiteKeyWidth = constraints.maxWidth / 6'), true);

    final gameStart = room.indexOf('class _ReferenceGameLogo');
    final rocketStart = room.indexOf('class _ReferenceRocketLogo');
    final tileStart = room.indexOf('class _ReferenceGameTile');
    expect(gameStart, greaterThanOrEqualTo(0));
    expect(rocketStart, greaterThan(gameStart));
    expect(tileStart, greaterThan(rocketStart));

    final gameLogo = room.substring(gameStart, rocketStart);
    final rocketLogo = room.substring(rocketStart, tileStart);
    expect(gameLogo.contains('Icons.sports_esports'), false);
    expect(rocketLogo.contains('Icons.rocket_launch'), false);
  });

  test('Rocket keeps the locked ten sequential stage requirements', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();

    for (final target in <int>[
      8000000,
      15000000,
      30000000,
      50000000,
      90000000,
      150000000,
      200000000,
      250000000,
      350000000,
      500000000,
    ]) {
      expect(
        room.contains(target.toString()),
        true,
        reason: 'Missing Rocket target: $target',
      );
    }
    expect(room.contains("Key('room-rocket-level-scroll')"), true);
    expect(room.contains("room-rocket-large-preview-"), true);
    expect(room.contains('_selectedRocketPreviewLevel'), true);
    expect(room.contains('onTap: ()'), true);
    expect(room.contains('ListView.builder'), true);
    expect(room.contains('thumbVisibility: true'), true);
    expect(room.contains('_rocketProgressState'), true);
    expect(
      room.contains(
        'Lucky gifts add 10% to Rocket. All other gifts add 100%.',
      ),
      true,
    );
  });
}
