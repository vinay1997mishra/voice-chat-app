import 'dart:convert';
import 'dart:io';

import 'package:livekit_client/livekit_client.dart';

import 'realtime.dart';

class LiveKitRtcAdapter implements RtcAdapter {
  LiveKitRtcAdapter({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  Room? _room;
  RtcConnectionState _state = RtcConnectionState.idle;
  bool _publishing = false;

  @override
  RtcConnectionState get state => _state;

  @override
  bool get publishingMic => _publishing;

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
    if (authToken == null || authToken.trim().isEmpty) {
      _state = RtcConnectionState.failed;
      throw StateError('Tinni login session is required for voice');
    }

    await leave();
    _state = RtcConnectionState.joining;

    Room? nextRoom;
    try {
      final credentials = await _fetchCredentials(
        roomId: roomId,
        authToken: authToken,
      );
      final serverUrl = credentials['server_url']?.toString() ?? '';
      final token = credentials['token']?.toString() ?? '';
      if (serverUrl.isEmpty || token.isEmpty) {
        throw StateError('LiveKit credentials are incomplete');
      }

      nextRoom = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      await nextRoom.prepareConnection(serverUrl, token);
      await nextRoom.connect(serverUrl, token);
      _room = nextRoom;
      _publishing = false;
      _state = RtcConnectionState.joined;
    } catch (error) {
      _state = RtcConnectionState.failed;
      _publishing = false;
      if (nextRoom != null) {
        try {
          await nextRoom.disconnect();
        } catch (_) {}
        try {
          await nextRoom.dispose();
        } catch (_) {}
      }
      _room = null;
      rethrow;
    }
  }

  @override
  Future<void> leave() async {
    final oldRoom = _room;
    _room = null;
    _publishing = false;

    if (oldRoom != null) {
      try {
        await oldRoom.disconnect();
      } finally {
        try {
          await oldRoom.dispose();
        } catch (_) {}
      }
    }

    _state = RtcConnectionState.idle;
  }

  @override
  Future<void> setMicPublished(bool enabled) async {
    if (_state != RtcConnectionState.joined || _room == null) {
      throw StateError('RTC room is not joined');
    }
    final participant = _room!.localParticipant;
    if (participant == null) {
      throw StateError('LiveKit local participant is unavailable');
    }

    await participant.setMicrophoneEnabled(enabled);
    _publishing = enabled;
  }

  Future<Map<String, dynamic>> _fetchCredentials({
    required String roomId,
    required String authToken,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/livekit/token'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(jsonEncode(<String, dynamic>{'room_id': roomId}));

    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    Map<String, dynamic> data = <String, dynamic>{};
    if (raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        data = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to connect voice room',
      );
    }
    return data;
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}
