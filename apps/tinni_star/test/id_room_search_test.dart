import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Discover search uses backend ID lookup for users and rooms', () {
    final screen = File('lib/screens/discover_screen.dart').readAsStringSync();
    final discovery =
        File('lib/discovery/discovery_service.dart').readAsStringSync();

    expect(screen, contains("Key('discover-search-field')"));
    expect(screen, contains('searchRoomRemote('));
    expect(screen, contains('searchUserById('));
    expect(screen, contains("Key('discover-user-result')"));
    expect(screen, contains('ChatUserProfileScreen('));
    expect(screen, contains('No matching user or room found.'));
    expect(discovery, contains("path: '/rooms/search'"));
  });
}
