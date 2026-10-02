import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner Members tab includes number and owner-approved Name ID search', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(source, contains("Key('room-admin-id-search-field')"));
    expect(source, contains("Key('room-admin-id-search-button')"));
    expect(source, contains("RegExp(r'[A-Za-z0-9_]')"));
    expect(source, contains("Search number ID / Name ID"));
    expect(source, contains("Key('room-admin-search-add-button')"));
    expect(source, contains('searchUserById('));
  });
}
