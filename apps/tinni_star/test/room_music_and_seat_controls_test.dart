import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seat-down and room-exit stop room music', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('stopForSeatDown(userId)'));
    expect(source, contains('stopRoomPlayback()'));
    expect(source, contains('Join a room seat before playing music.'));
  });

  test('owner admin empty seat tap opens full seat controls', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('if (_canModerateSeats && !occupied)'));
    expect(source, contains("_showSeatControls(index);"));
    expect(source, contains("Key('seat-control-lock')"));
    expect(source, contains("Key('seat-control-mute')"));
    expect(source, contains("Key('seat-control-take')"));
  });
}
