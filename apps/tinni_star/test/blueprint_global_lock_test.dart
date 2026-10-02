import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const marker = 'GLOBAL_CHANGE_LOCK_V1';
  const canonicalPath =
      '../../docs/TINNI_STAR_COMPLETE_IMPLEMENTATION_BLUEPRINT_V3.md';
  const lockPath = '../../docs/TINNI_STAR_GLOBAL_CHANGE_LOCK.md';

  test('canonical Tinni Star blueprint keeps the global user-authority lock', () {
    for (final path in <String>[canonicalPath, lockPath]) {
      final file = File(path);
      expect(file.existsSync(), true, reason: 'Missing locked blueprint: $path');
      final content = file.readAsStringSync();
      expect(content.contains(marker), true);
      expect(content.contains('latest explicit user instruction wins'), true);
      expect(
        content.toLowerCase().contains(
          'if the user has not asked to change it, keep it as it is',
        ),
        true,
      );
    }
  });

  test('legacy Tinni Star blueprint files stay removed', () {
    const retired = <String>[
      '../../docs/TINNI_STAR_YOHOO_MERGED_BLUEPRINT_V2.md',
      'docs/TINNI_PRODUCT_BLUEPRINT.md',
      'docs/BLUEPRINT_STATUS.md',
    ];
    for (final path in retired) {
      expect(
        File(path).existsSync(),
        false,
        reason: 'Legacy blueprint must not return: $path',
      );
    }
  });

  test('latest seat and gifting locks remain in canonical blueprint', () {
    final content = File(canonicalPath).readAsStringSync();
    expect(content.contains('42 seats = 6 seats per row × 7 rows'), true);
    expect(content.contains('Old 7×6 / 7-seats-per-row layout is forbidden'), true);
    expect(content.contains('blurred/dimmed with gold check/glow'), true);
    expect(content.contains('visible **12-second countdown**'), true);
    expect(content.contains('simultaneous fan-out to all selected seats'), true);
  });
}
