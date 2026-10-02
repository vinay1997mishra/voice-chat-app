import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile placeholder identity boxes stay removed', () {
    final profile = File('lib/screens/public_profile_screen.dart').readAsStringSync();
    expect(profile.contains("'Non-VIP'"), false);
    expect(profile.contains("'Incomplete'"), false);
    expect(profile.contains("Key('profile-identity-tags')"), true);
    expect(profile.contains("Key('profile-v-official-tag')"), true);
    expect(profile.contains("RoyalPalette.gold"), true);
    final mine = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(mine.contains("decoded['identity_tags']"), true);
    expect(mine.contains("Key('mine-profile-identity-tags')"), true);
    expect(mine.contains("Key('mine-profile-v-official-tag')"), true);
  });

  test('Messages & Tags keeps V Official owner controls', () {
    final html = File('../tinni_owner_panel/index.html').readAsStringSync();
    final js = File('../tinni_owner_panel/app.js').readAsStringSync();
    expect(html.contains('Messages & Tags'), true);
    expect(html.contains('V Official Tag'), true);
    expect(html.contains('ownerVDesignation'), true);
    for (final color in <String>[
      'Sky Blue',
      'Light Green',
      'Golden',
      'Black',
      'Red',
      'Purple',
    ]) {
      expect(html.contains(color), true, reason: 'Missing V background: $color');
    }
    expect(js.contains('data-owner-v-official-selected'), true);
    expect(js.contains('"v_official"'), true);
  });

  test('V Official management stays Owner Master Panel only', () {
    final lib = Directory('lib');
    final source = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    for (final forbidden in <String>[
      'Apply V Official to Selected',
      'ownerVDesignation',
      'ownerVBackground',
      '/api/owner/officials',
      'data-owner-v-official-selected',
      'data-owner-official-remove',
      'data-owner-official-edit',
    ]) {
      expect(
        source.contains(forbidden),
        false,
        reason: 'Owner-only V Official management leaked into APK: $forbidden',
      );
    }
  });

  test('public profile keeps identity tags when another request fails', () {
    final profile =
        File('lib/screens/public_profile_screen.dart').readAsStringSync();
    expect(profile.contains('_safeProfileLoad'), true);
    expect(profile.contains("tagData['identity_tags']"), true);
    expect(profile.contains("Key('profile-identity-tags')"), true);
  });

  test('backend keeps V tag metadata and automatic Host Agency identity', () {
    final directory =
        File('../tinni_worker/src/app_directory.js').readAsStringSync();
    expect(directory.contains("kind TEXT NOT NULL DEFAULT 'custom'"), true);
    expect(directory.contains('designation TEXT NOT NULL'), true);
    expect(directory.contains('background_color TEXT'), true);
    expect(directory.contains('listUserIdentityTags'), true);
    expect(directory.contains("role IN ('host','agency')"), true);
  });

  test('message conversation exposes target identity tags', () {
    final messages = File('lib/screens/messages_screen.dart').readAsStringSync();
    expect(messages.contains("tagData['identity_tags']"), true);
    expect(messages.contains("Key('message-identity-tags')"), true);
  });

  test('canonical blueprint locks Messages & Tags identity behavior', () {
    final blueprint = File(
      '../../docs/TINNI_STAR_COMPLETE_IMPLEMENTATION_BLUEPRINT_V3.md',
    ).readAsStringSync();
    expect(blueprint.contains('Messages & Tags / V Official identity'), true);
    expect(blueprint.contains('Do not rename it to Tags/Medals'), true);
    expect(blueprint.contains('Non-VIP'), true);
    expect(blueprint.contains('Incomplete'), true);
  });
}
