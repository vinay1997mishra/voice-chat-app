import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner Members tab includes numeric ID admin search', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(source, contains("Key('room-admin-id-search-field')"));
    expect(source, contains("Key('room-admin-id-search-button')"));
    expect(source, contains('FilteringTextInputFormatter.digitsOnly'));
    expect(source, contains("Search user ID to make Admin"));
    expect(source, contains("Key('room-admin-search-add-button')"));
    expect(source, contains('searchUserById('));
  });
}
