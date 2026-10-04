import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Free Mic remains server-authoritative in the room UI', () {
    final roomScreen = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(roomScreen, contains("setRoomMicMode("));
    expect(roomScreen, contains("value ? 'free' : 'apply'"));
    expect(
      roomScreen,
      contains("if (_canModerateSeats || !controller.inviteMode)"),
    );
    expect(roomScreen, contains('takeMySeat(index)'));
  });

  test('live seat-count changes resize the active room for real users', () {
    final presence =
        File('lib/room/room_presence_service.dart').readAsStringSync();
    final session =
        File('lib/room/active_room_session.dart').readAsStringSync();

    expect(presence, contains('int? seatCount;'));
    expect(presence, contains("data.containsKey('seat_count')"));
    expect(session, contains('final serverSeatCount = presence.seatCount;'));
    expect(session, contains('roomController.setSeatCount(serverSeatCount);'));
  });

  test('Mine keeps the active owned room instead of showing Create again', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(home, contains('final activeRoom = widget.state.roomSession.room;'));
    expect(home, contains('activeRoom.ownerId == currentUserId'));
    expect(
      home,
      contains('final myRoom = owned.isNotEmpty ? owned.first : activeOwnedRoom;'),
    );
  });

  test('main in-room title pill shows room name without room ID underneath', () {
    final roomScreen = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = roomScreen.indexOf("Key('reference-room-title-pill')");
    final end = roomScreen.indexOf('actions: [', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final header = roomScreen.substring(start, end);
    expect(header, contains('_roomTitle'));
    expect(header, isNot(contains('_roomSnapshot.displayId')));
  });

  test('minimized room bar renders the real room DP and room name', () {
    final app = File('lib/app/tinni_app.dart').readAsStringSync();
    final start = app.indexOf('class _MiniRoomBar');
    expect(start, greaterThanOrEqualTo(0));
    final mini = app.substring(start);
    expect(mini, contains('displayRoom.photoDataUrl'));
    expect(mini, contains('backgroundImage: roomDp'));
    expect(mini, contains('final roomName = displayRoom.title.trim().isNotEmpty'));
    expect(mini, contains('roomName,'));
  });
}
