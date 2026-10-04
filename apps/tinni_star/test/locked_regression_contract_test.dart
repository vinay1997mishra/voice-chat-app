import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/i18n/tinni_localization.dart';

void main() {
  test('shared language registry stays complete and English-first', () {
    expect(tinniSupportedLanguages.first, 'English');
    expect(
      tinniSupportedLanguages,
      containsAll(<String>[
        'English',
        'Hindi',
        'Urdu',
        'Arabic',
        'Bengali',
        'Malayalam',
        'Filipino (Tagalog)',
        'Persian (Farsi)',
        'Kurdish',
        'Baluchi',
        'Chinese (Simplified)',
        'Chinese (Traditional)',
        'Korean',
      ]),
    );

    final settings = File('lib/screens/mine_function_screens.dart').readAsStringSync();
    final login = File('lib/screens/login_screen.dart').readAsStringSync();
    expect(settings, contains('const values = tinniSupportedLanguages;'));
    expect(login, contains("key: const Key('create-id-language')"));
    expect(login, contains('items: tinniSupportedLanguages'));
  });

  test('retired Mine entries stay removed', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(profile, isNot(contains("Key('mine-personal-information')")));
    expect(profile, isNot(contains("label: 'Personal information'")));
    expect(profile, isNot(contains("Key('mine-props')")));
  });

  test('locked wallet entry points cannot disappear', () {
    final recharge = File('lib/screens/recharge_screen.dart').readAsStringSync();
    final details = File('lib/screens/wallet_detail_screens.dart').readAsStringSync();
    final backend = File('lib/infra/app_backend_service.dart').readAsStringSync();

    expect(recharge, contains('CoinsHistoryScreen'));
    expect(recharge, contains('DiamondsWalletScreen'));
    expect(recharge, contains('RoleWalletDetailScreen'));
    expect(details, contains('class CoinsHistoryScreen'));
    expect(details, contains('class SellerReceivedCoinsScreen'));
    expect(details, contains('class DiamondsWalletScreen'));
    expect(details, contains('class RoleWalletDetailScreen'));
    expect(details, contains('class ReceivedDollarsScreen'));

    expect(backend, contains("'/wallet/coins/history'"));
    expect(backend, contains("'/wallet/diamonds/history'"));
    expect(backend, contains("'/wallet/diamonds/convert'"));
    expect(backend, contains("'/wallet/role-detail'"));
    expect(backend, contains("'/wallet/role-dollars/transfer'"));
  });

  test('locked dollar wallets keep manual USD flow and crypto destination', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final hierarchy =
        File('lib/screens/mine_function_screens.dart').readAsStringSync();
    final details =
        File('lib/screens/wallet_detail_screens.dart').readAsStringSync();
    final backend = File('lib/infra/app_backend_service.dart').readAsStringSync();

    expect(profile, contains('settlementRecipients(account.authToken)'));
    expect(profile, contains("'Coin Sellers'"));
    expect(profile, contains("'Merchants'"));
    expect(profile, contains('recipientRole: recipient.role'));
    expect(hierarchy, contains("Key('role-dollar-wallet-open')"));
    expect(hierarchy, contains("Key('role-dollar-wallet-send')"));
    expect(hierarchy, contains("'Dollar Wallet'"));
    expect(details, contains('minimum_transfer_usd_cents'));
    expect(details, contains("'Cryptocurrency (USDT)'"));
    expect(details, contains("'USDT wallet address'"));
    expect(details, contains("Key('role-wallet-send-dollars')"));
    expect(details, contains("'Open Dollar Wallet'"));
    expect(details, isNot(contains("value: 'merchant'")));
    expect(backend, contains("'/wallet/settlement/recipients'"));
    expect(backend, contains("'recipient_role': recipientRole"));
    expect(backend, contains("'usdt_address': usdtAddress"));
  });

  test('Popular and New stay limited to online rooms', () {
    final discovery =
        File('lib/discovery/discovery_service.dart').readAsStringSync();
    expect(discovery, contains('room.online > 0'));
    expect(discovery, contains('Empty rooms stay available'));
  });

  test('latest room comment layout stays locked and old tag UI stays removed', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(room, contains("Key(\n              'room-comment-tag-'"));
    expect(room, contains('controller: _roomMessageScrollController'));
    expect(room, contains('_scrollRoomCommentsToNewest();'));
    expect(room, contains('horizontal: 8, vertical: 3'));
    expect(room, contains('fontSize: 11.5'));
    expect(room, isNot(contains('room-live-owner-badges')));
    expect(room, isNot(contains('live-owner-tag-')));
    expect(room, isNot(contains('full-profile-tag-')));
    expect(room, isNot(contains('room-owner-tag-')));
    expect(room, isNot(contains('seat-owner-tag-')));
    expect(room, isNot(contains('seat-owner-medal-')));
  });

  test('removed room support banner and lucky live feed stay removed', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(room, isNot(contains('Ask your followers to support the room.')));
    expect(room, isNot(contains("Key('lucky-live-feed-overlay')")));
    expect(room, isNot(contains('_buildLuckyFeedOverlay()')));
    expect(room, isNot(contains('_refreshLuckyFeed()')));
  });

  test('room game logo and Rocket stages stay on latest reference layout', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(room, contains("Key('room-rocket-floating-button')"));
    expect(room, contains("Key('realistic-black-rocket-logo')"));
    expect(room, contains('class _StealthRocketPainter'));
    final rocketLogoStart = room.indexOf('class _ReferenceRocketLogo');
    final rocketPainterStart = room.indexOf('class _StealthRocketPainter');
    expect(rocketLogoStart, greaterThanOrEqualTo(0));
    expect(rocketPainterStart, greaterThan(rocketLogoStart));
    final floatingRocketLogo =
        room.substring(rocketLogoStart, rocketPainterStart);
    expect(floatingRocketLogo, isNot(contains('Icons.rocket_launch_rounded')));
    expect(floatingRocketLogo, isNot(contains('Color(0xFFFF63E6)')));
    expect(room, contains("Key('room-game-floating-button')"));
    expect(room, contains('child: const _ReferenceGameLogo(size: 54)'));
    expect(room, contains("Key('game-keyboard-logo')"));
    expect(room, contains('width: size'));
    expect(room, contains('height: size * 0.66'));
    expect(room, contains('whiteKeyWidth = constraints.maxWidth / 6'));
    expect(room, isNot(contains("Key('room-tool-game')")));
    for (final target in <String>[
      '8000000',
      '15000000',
      '30000000',
      '50000000',
      '90000000',
      '150000000',
      '200000000',
      '250000000',
      '350000000',
      '500000000',
    ]) {
      expect(room, contains(target));
    }
  });

  test('gift panel locked categories and Lucky presets stay present', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    for (final category in <String>['Normal', 'Lucky', 'CP', 'Country', 'Luxury']) {
      expect(room, contains("'$category'"));
    }
    expect(room, isNot(contains("'Popular', 'Lucky'")));
    expect(room, contains("Key('lucky-quantity-plus')"));
    expect(room, contains("Key('lucky-quantity-presets')"));
    for (final quantity in <String>['9', '21', '51', '99', '199', '599', '899', '2999', '7999']) {
      expect(room, contains(quantity));
    }
  });

  test('canonical and active locked blueprint files remain in repository', () {
    expect(
      File('../../docs/TINNI_STAR_COMPLETE_IMPLEMENTATION_BLUEPRINT_V3.md')
          .existsSync(),
      isTrue,
    );
    expect(File('../../docs/TINNI_STAR_GLOBAL_CHANGE_LOCK.md').existsSync(), isTrue);
    expect(File('docs/LOCKED_REGRESSION_CONTRACT.md').existsSync(), isTrue);
    expect(File('WALLET_LANGUAGE_BLUEPRINT.md').existsSync(), isTrue);
  });
}
