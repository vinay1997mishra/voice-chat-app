import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/i18n/tinni_localization.dart';

void main() {
  test('English is the localization fallback', () {
    expect(tinniText('', 'wallet'), 'Wallet');
    expect(tinniText('unknown', 'message'), 'Message');
    expect(tinniText('English', 'setting'), 'Setting');
  });

  test('user-facing Dart has no hardcoded Hindi or Urdu outside i18n', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.replaceAll('\\', '/').contains('/i18n/'));

    final nonEnglishScript = RegExp(r'[\u0900-\u097F\u0600-\u06FF]');
    final violations = <String>[];
    for (final file in files) {
      if (nonEnglishScript.hasMatch(file.readAsStringSync())) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Default app copy must stay English. Put Hindi/Urdu only in i18n and show it after the user changes Language Settings.',
    );
  });

  test('app state keeps English as the default language', () {
    final source = File('lib/app/tinni_state.dart').readAsStringSync();
    expect(
      source.contains("ValueNotifier<String>('English')"),
      isTrue,
      reason: 'Tinni Star must open in English until the user changes language.',
    );
  });
}
