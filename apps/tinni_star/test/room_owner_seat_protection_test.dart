import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin cannot control owner seat and owner can seat down admins', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('Admin cannot mute, lock or seat down the room owner.'));
    expect(source, contains("label: 'Seat down'"));
    expect(source, contains("Key('seat-control-down')"));
    expect(source, contains('_isRoomOwner || !currentMember.isAdmin'));
  });
}
