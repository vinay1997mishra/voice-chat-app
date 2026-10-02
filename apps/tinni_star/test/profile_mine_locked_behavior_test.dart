import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mine keeps Props and Personal information menu options removed', () {
    final source = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(source.contains("Key('mine-props')"), false);
    expect(source.contains("Key('mine-personal-information')"), false);
    expect(source.contains("tinniText(language, 'props')"), false);
    expect(source.contains("PersonalProfileScreen(state: widget.state)"), false);
  });

  test('UID long press copy and floating confirmation stay on profile surfaces', () {
    final mine = File('lib/screens/profile_screen.dart').readAsStringSync();
    final publicProfile =
        File('lib/screens/public_profile_screen.dart').readAsStringSync();
    final personal =
        File('lib/screens/personal_profile_screen.dart').readAsStringSync();

    expect(mine.contains("Key('mine-uid-long-press')"), true);
    expect(publicProfile.contains("Key('public-profile-uid-long-press')"), true);
    expect(personal.contains("Key('personal-profile-uid-long-press')"), true);

    for (final source in <String>[mine, publicProfile, personal]) {
      expect(source.contains('onLongPress:'), true);
      expect(source.contains('Clipboard.setData'), true);
      expect(source.contains('SnackBarBehavior.floating'), true);
      expect(source.contains('ID copy ho gaya'), true);
    }
  });

  test('cover photo removal is explicit and profile save does not clear cover', () {
    final personal =
        File('lib/screens/personal_profile_screen.dart').readAsStringSync();
    final backend =
        File('lib/infra/app_backend_service.dart').readAsStringSync();

    expect(personal.contains("Key('profile-cover-remove')"), true);
    expect(personal.contains("Key('profile-cover-remove-confirm')"), true);
    expect(personal.contains("deleteProfileMedia("), true);
    expect(personal.contains("'cover'"), true);
    expect(backend.contains("'confirm_remove': true"), true);
  });

  test('canonical blueprint locks Mine copy and persistent cover rules', () {
    final blueprint = File(
      '../../docs/TINNI_STAR_COMPLETE_IMPLEMENTATION_BLUEPRINT_V3.md',
    ).readAsStringSync();
    expect(blueprint.contains('Mine must not show Props'), true);
    expect(
      blueprint.contains(
        'Mine must not show Personal information / Profile Information',
      ),
      true,
    );
    expect(blueprint.contains('ID copy ho gaya'), true);
    expect(blueprint.contains('cover photo is persistent'), true);
    expect(blueprint.contains('explicit removal confirmation'), true);
  });
}
