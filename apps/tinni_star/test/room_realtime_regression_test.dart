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

  test('room stays online through websocket reconnect fallback', () {
    final session =
        File('lib/room/active_room_session.dart').readAsStringSync();
    expect(
      session,
      contains('Timer.periodic(const Duration(minutes: 1)'),
    );
    expect(session, contains('if (presence.liveConnected) return;'));
    expect(session, contains('await presence.heartbeat('));
    expect(session, contains('await presence.connectLive('));
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

  test('main in-room title pill keeps room name and Room ID together', () {
    final roomScreen = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = roomScreen.indexOf("Key('reference-room-title-pill')");
    final end = roomScreen.indexOf('actions: [', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final header = roomScreen.substring(start, end);
    expect(header, contains('_roomTitle'));
    expect(header, contains('_roomSnapshot.displayId'));
  });

  test('minimized room bar renders the real room DP and room name', () {
    final app = File('lib/app/tinni_app.dart').readAsStringSync();
    final start = app.indexOf('class _MiniRoomBar');
    expect(start, greaterThanOrEqualTo(0));
    final mini = app.substring(start);
    expect(mini, contains("Key('mini-room-dp')"));
    expect(mini, contains('RoomDp('));
    expect(mini, contains('room: displayRoom'));
    expect(mini, contains('fit: BoxFit.cover'));
    expect(mini, contains('final roomName = displayRoom.title.trim().isNotEmpty'));
    expect(mini, contains('roomName,'));
  });

  test('room presence retries immediately and backs off prolonged outages to protect quota', () {
    final session =
        File('lib/room/active_room_session.dart').readAsStringSync();
    final presence =
        File('lib/room/room_presence_service.dart').readAsStringSync();
    final budget = File('lib/infra/request_budget.dart').readAsStringSync();
    expect(session, contains('_presenceRecoveryTimer'));
    expect(session, contains('int _presenceRecoveryFailures = 0;'));
    expect(session, contains('_schedulePresenceRecovery(immediate: true)'));
    expect(
      session,
      contains('RequestBudget.reconnectDelay(_presenceRecoveryFailures)'),
    );
    expect(
      session,
      contains('(_presenceRecoveryFailures + 1).clamp(0, 4).toInt()'),
    );
    expect(
      presence,
      contains('RequestBudget.reconnectDelay(_liveReconnectFailures)'),
    );
    expect(
      presence,
      contains('(_liveReconnectFailures + 1).clamp(0, 4).toInt()'),
    );
    expect(presence, contains('math.Random().nextInt(800)'));
    expect(
      budget,
      contains('List<int> _socketFallbackSeconds = <int>[3, 5, 8, 10]'),
    );
    expect(session, contains('await presence.join('));
    expect(session, contains("throw StateError('Room presence reconnect pending')"));
  });

  test('real connection failure stays visible and healthy HTTP fallback avoids a permanent warning', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final presence =
        File('lib/room/room_presence_service.dart').readAsStringSync();
    final state = File('lib/app/tinni_state.dart').readAsStringSync();

    expect(room, contains("Key('room-connection-retrying')"));
    expect(room, contains("presence.hasConnectionProblem"));
    expect(room, contains("'Voice unavailable • Tap to retry'"));
    expect(room, contains("'Connection problem • retrying…'"));
    expect(presence, contains('bool liveReconnecting = false;'));
    expect(presence, contains("'room_transport_failure'"));
    expect(presence, contains("'room_presence_request_failure'"));
    expect(state, contains('roomPresence.diagnosticSink = analytics.event;'));
  });

}
