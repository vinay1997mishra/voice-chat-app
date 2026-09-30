import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room members panel exposes owner-only admin controls', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(
      source,
      contains("'room-member-remove-admin-'"),
    );
    expect(
      source,
      contains("child: const Text('Remove')"),
    );
    expect(
      source,
      contains("'room-member-add-admin-'"),
    );
    expect(
      source,
      contains("child: const Text('Add Admin')"),
    );
    expect(
      source,
      contains("trailing = _isRoomOwner"),
    );
    expect(
      source,
      contains("else if (_isRoomOwner)"),
    );
  });
}
