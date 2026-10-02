import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const marker = 'GLOBAL_CHANGE_LOCK_V1';
  const lockedBlueprints = <String>[
    '../../docs/TINNI_STAR_COMPLETE_IMPLEMENTATION_BLUEPRINT_V3.md',
    '../../docs/TINNI_STAR_YOHOO_MERGED_BLUEPRINT_V2.md',
    '../../docs/TINNI_STAR_GLOBAL_CHANGE_LOCK.md',
    'docs/TINNI_PRODUCT_BLUEPRINT.md',
    'docs/BLUEPRINT_STATUS.md',
  ];

  test('all Tinni Star blueprints keep the global user-authority change lock', () {
    for (final path in lockedBlueprints) {
      final file = File(path);
      expect(file.existsSync(), true, reason: 'Missing locked blueprint: $path');
      final content = file.readAsStringSync();
      expect(
        content.contains(marker),
        true,
        reason: 'Global change lock was removed from $path',
      );
      expect(
        content.contains('latest explicit user instruction wins'),
        true,
        reason: 'Latest-user-instruction precedence is missing from $path',
      );
      expect(
        content.contains('if the user has not asked to change it, keep it as it is'),
        true,
        reason: 'Default preserve-current-behavior rule is missing from $path',
      );
    }
  });
}
