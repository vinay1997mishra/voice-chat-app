import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum RtcConnectionState { idle, joining, joined, reconnecting, failed }

abstract interface class RtcAdapter {
  RtcConnectionState get state;
  bool get publishingMic;
  ValueListenable<Map<String, double>> get speakingLevelsListenable;
  Future<void> join(
    String roomId,
    String userId, {
    String? authToken,
  });
  Future<void> leave();
  Future<void> setMicPublished(bool enabled);
  Future<void> setRemoteAudioEnabled(bool enabled);
}

abstract interface class ImAdapter {
  bool get connected;
  Future<void> connect(String userId, {String? authToken});
  Future<void> joinRoom(String roomId);
  Future<void> leaveRoom(String roomId);
  Future<void> sendRoomEvent(String roomId, Map<String, Object?> event);
}

class LocalRtcAdapter implements RtcAdapter {
  RtcConnectionState _state = RtcConnectionState.idle;
  bool _publishing = false;
  final ValueNotifier<Map<String, double>> _speakingLevels =
      ValueNotifier<Map<String, double>>(const <String, double>{});

  @override
  RtcConnectionState get state => _state;

  @override
  bool get publishingMic => _publishing;

  @override
  ValueListenable<Map<String, double>> get speakingLevelsListenable =>
      _speakingLevels;

  @override
  Future<void> join(
    String roomId,
    String userId, {
    String? authToken,
  }) async {
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

  @override
  Future<void> setRemoteAudioEnabled(bool enabled) async {}
}

class LocalImAdapter implements ImAdapter {
  bool _connected = false;
  final Set<String> joinedRooms = <String>{};
  final List<Map<String, Object?>> sentEvents = <Map<String, Object?>>[];

  @override
  bool get connected => _connected;

  @override
  Future<void> connect(String userId, {String? authToken}) async {
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

class BackendImAdapter implements ImAdapter {
  BackendImAdapter({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;
  final Set<String> joinedRooms = <String>{};
  bool _connected = false;
  String? _authToken;
  String? _userId;

  @override
  bool get connected => _connected;

  @override
  Future<void> connect(String userId, {String? authToken}) async {
    if (userId.trim().isEmpty) throw StateError('userId is required');
    if (authToken == null || authToken.trim().isEmpty) {
      throw StateError('Authenticated IM session is required');
    }
    _userId = userId;
    _authToken = authToken;
    _connected = true;
  }

  @override
  Future<void> joinRoom(String roomId) async {
    if (!_connected) throw StateError('IM is not connected');
    if (roomId.trim().isEmpty) throw StateError('roomId is required');
    joinedRooms.add(roomId);
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    joinedRooms.remove(roomId);
  }

  @override
  Future<void> sendRoomEvent(
    String roomId,
    Map<String, Object?> event,
  ) async {
    if (!_connected || !joinedRooms.contains(roomId)) {
      throw StateError('IM room is not joined');
    }
    final token = _authToken;
    if (token == null || token.isEmpty) {
      throw StateError('Authenticated IM session is required');
    }

    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/room-events'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ' + token,
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    request.write(
      jsonEncode(<String, Object?>{
        'room_id': roomId,
        'event': <String, Object?>{
          ...event,
          'userId': event['userId'] ?? _userId,
        },
      }),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Room event failed';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['error'] != null) {
          message = decoded['error'].toString();
        }
      } catch (_) {}
      throw StateError(message);
    }
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}

class RealtimeCoordinator {
  RealtimeCoordinator({required this.rtc, required this.im});

  final RtcAdapter rtc;
  final ImAdapter im;
  String? activeRoomId;
  String? userId;

  Future<void> enterRoom(
    String roomId,
    String userId, {
    String? authToken,
  }) async {
    this.userId = userId;
    await im.connect(userId, authToken: authToken);
    await im.joinRoom(roomId);
    try {
      await rtc.join(
        roomId,
        userId,
        authToken: authToken,
      );
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

  Future<void> setRemoteAudioEnabled(bool enabled) async {
    if (activeRoomId == null) throw StateError('No active room');
    await rtc.setRemoteAudioEnabled(enabled);
  }

  Future<void> exitRoom() async {
    final roomId = activeRoomId;
    if (roomId == null) return;
    await rtc.leave();
    await im.leaveRoom(roomId);
    activeRoomId = null;
  }
}
