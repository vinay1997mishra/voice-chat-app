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
    expect(room.contains("Key('room-rocket-ten-stages')"), true);
    expect(room.contains('_rocketProgressState'), true);
    expect(
      room.contains(
        'Lucky gifts add 10% to Rocket. All other gifts add 100%.',
      ),
      true,
    );
  });
}
