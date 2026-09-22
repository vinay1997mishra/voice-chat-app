enum RtcConnectionState { idle, joining, joined, reconnecting, failed }

abstract interface class RtcAdapter {
  RtcConnectionState get state;
  bool get publishingMic;
  Future<void> join(String roomId, String userId);
  Future<void> leave();
  Future<void> setMicPublished(bool enabled);
}

abstract interface class ImAdapter {
  bool get connected;
  Future<void> connect(String userId);
  Future<void> joinRoom(String roomId);
  Future<void> leaveRoom(String roomId);
  Future<void> sendRoomEvent(String roomId, Map<String, Object?> event);
}

class LocalRtcAdapter implements RtcAdapter {
  RtcConnectionState _state = RtcConnectionState.idle;
  bool _publishing = false;

  @override
  RtcConnectionState get state => _state;

  @override
  bool get publishingMic => _publishing;

  @override
  Future<void> join(String roomId, String userId) async {
    if (roomId.isEmpty || userId.isEmpty) {
      _state = RtcConnectionState.failed;
      throw StateError('roomId and userId are required');
    }
    _state = RtcConnectionState.joining;
    _state = RtcConnectionState.joined;
  }

  @override
  Future<void> leave() async {
    _publishing = false;
    _state = RtcConnectionState.idle;
  }

  @override
  Future<void> setMicPublished(bool enabled) async {
    if (_state != RtcConnectionState.joined) {
      throw StateError('RTC room is not joined');
    }
    _publishing = enabled;
  }
}

class LocalImAdapter implements ImAdapter {
  bool _connected = false;
  final Set<String> joinedRooms = <String>{};
  final List<Map<String, Object?>> sentEvents = <Map<String, Object?>>[];

  @override
  bool get connected => _connected;

  @override
  Future<void> connect(String userId) async {
    if (userId.isEmpty) throw StateError('userId is required');
    _connected = true;
  }

  @override
  Future<void> joinRoom(String roomId) async {
    if (!_connected) throw StateError('IM is not connected');
    joinedRooms.add(roomId);
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    joinedRooms.remove(roomId);
  }

  @override
  Future<void> sendRoomEvent(String roomId, Map<String, Object?> event) async {
    if (!joinedRooms.contains(roomId)) {
      throw StateError('IM room is not joined');
    }
    sentEvents.add(Map<String, Object?>.unmodifiable({
      'roomId': roomId,
      ...event,
    }));
  }
}

class RealtimeCoordinator {
  RealtimeCoordinator({required this.rtc, required this.im});

  final RtcAdapter rtc;
  final ImAdapter im;
  String? activeRoomId;
  String? userId;

  Future<void> enterRoom(String roomId, String userId) async {
    this.userId = userId;
    await im.connect(userId);
    await im.joinRoom(roomId);
    try {
      await rtc.join(roomId, userId);
      activeRoomId = roomId;
    } catch (_) {
      await im.leaveRoom(roomId);
      rethrow;
    }
  }

  Future<void> setMic(bool enabled) async {
    final roomId = activeRoomId;
    if (roomId == null) throw StateError('No active room');
    await rtc.setMicPublished(enabled);
    await im.sendRoomEvent(roomId, {
      'type': 'mic_state',
      'enabled': enabled,
      'userId': userId,
    });
  }

  Future<void> exitRoom() async {
    final roomId = activeRoomId;
    if (roomId == null) return;
    await rtc.leave();
    await im.leaveRoom(roomId);
    activeRoomId = null;
  }
}
