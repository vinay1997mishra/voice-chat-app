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

  test('locked seller and merchant dollar limits stay visible in source contract', () {
    final details = File('lib/screens/wallet_detail_screens.dart').readAsStringSync();
    expect(details, contains('minimum_transfer_usd_cents'));
    expect(details, contains("'Dollar Transfer"));
    expect(details, contains("'Merchant'"));
    expect(details, contains("'Company'"));
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

  test('locked blueprint files remain in repository', () {
    expect(File('docs/TINNI_PRODUCT_BLUEPRINT.md').existsSync(), isTrue);
    expect(File('docs/LOCKED_REGRESSION_CONTRACT.md').existsSync(), isTrue);
    expect(File('WALLET_LANGUAGE_BLUEPRINT.md').existsSync(), isTrue);
  });
}
