import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'backend_http.dart';

import 'package:flutter/foundation.dart';
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
  bool _publishingCamera = false;
  bool _remoteAudioEnabled = true;
  Timer? _speakingTimer;
  int _generation = 0;
  bool _applyingAudioPreference = false;
  final ValueNotifier<Map<String, double>> _speakingLevels =
      ValueNotifier<Map<String, double>>(const <String, double>{});

  @override
  RtcConnectionState get state {
    final current = _room;
    if (current == null) return _state;
    switch (current.connectionState.name) {
      case 'connected': return RtcConnectionState.joined;
      case 'reconnecting': return RtcConnectionState.reconnecting;
      case 'disconnected': return RtcConnectionState.failed;
      default: return _state;
    }
  }

  @override
  bool get publishingMic => _publishing;

  @override
  ValueListenable<Map<String, double>> get speakingLevelsListenable =>
      _speakingLevels;

  bool get publishingCamera => _publishingCamera;

  Room? get room => _room;

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
    final generation = ++_generation;
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

      if (generation != _generation) throw StateError('Voice join was cancelled');
      nextRoom = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      await nextRoom.prepareConnection(serverUrl, token).timeout(const Duration(seconds: 10));
      await nextRoom.connect(serverUrl, token).timeout(const Duration(seconds: 25));
      if (generation != _generation) throw StateError('Voice join was cancelled');
      _room = nextRoom;
      _publishing = false;
      _publishingCamera = false;
      _state = RtcConnectionState.joined;
      await _applyRemoteAudioPreference();
      _startSpeakingMonitor();
    } catch (error) {
      if (generation == _generation) {
        _stopSpeakingMonitor();
        _state = RtcConnectionState.failed;
        _publishing = false;
      }
      if (nextRoom != null) {
        try {
          await nextRoom.disconnect();
        } catch (_) {}
        try {
          await nextRoom.dispose();
        } catch (_) {}
      }
      if (generation == _generation) _room = null;
      rethrow;
    }
  }

  @override
  Future<void> leave() async {
    _generation++;
    _stopSpeakingMonitor();
    final oldRoom = _room;
    _room = null;
    _publishing = false;
    _publishingCamera = false;
    _remoteAudioEnabled = true;

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
    if (state != RtcConnectionState.joined || _room == null) {
      throw StateError('RTC room is not joined');
    }
    final participant = _room!.localParticipant;
    if (participant == null) {
      throw StateError('LiveKit local participant is unavailable');
    }

    await participant.setMicrophoneEnabled(enabled);
    _publishing = enabled;
  }

  @override
  Future<void> setRemoteAudioEnabled(bool enabled) async {
    _remoteAudioEnabled = enabled;
    await _applyRemoteAudioPreference();
  }

  void _startSpeakingMonitor() {
    _speakingTimer?.cancel();
    _sampleSpeakingLevels();
    _speakingTimer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _sampleSpeakingLevels(),
    );
  }

  void _stopSpeakingMonitor() {
    _speakingTimer?.cancel();
    _speakingTimer = null;
    if (_speakingLevels.value.isNotEmpty) {
      _speakingLevels.value = const <String, double>{};
    }
  }

  void _sampleSpeakingLevels() {
    final currentRoom = _room;
    if (currentRoom == null || state != RtcConnectionState.joined) {
      if (_speakingLevels.value.isNotEmpty) {
        _speakingLevels.value = const <String, double>{};
      }
      return;
    }

    if (!_remoteAudioEnabled && !_applyingAudioPreference) {
      unawaited(_applyRemoteAudioPreference().catchError((Object _) {}));
    }
    final next = <String, double>{};
    for (final participant in currentRoom.activeSpeakers) {
      final identity = participant.identity.trim();
      if (identity.isEmpty || !participant.isSpeaking || participant.isMuted) {
        continue;
      }
      final level = participant.audioLevel.clamp(0.0, 1.0).toDouble();
      if (level < 0.01) continue;
      next[identity] = level;
    }

    final previous = _speakingLevels.value;
    if (_sameSpeakingLevels(previous, next)) return;
    _speakingLevels.value = Map<String, double>.unmodifiable(next);
  }

  bool _sameSpeakingLevels(
    Map<String, double> previous,
    Map<String, double> next,
  ) {
    if (previous.length != next.length) return false;
    for (final entry in next.entries) {
      final old = previous[entry.key];
      if (old == null || (old - entry.value).abs() > 0.025) {
        return false;
      }
    }
    return true;
  }

  Future<void> _applyRemoteAudioPreference() async {
    final room = _room;
    if (room == null || state != RtcConnectionState.joined || _applyingAudioPreference) return;
    _applyingAudioPreference = true;
    try {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        if (_remoteAudioEnabled) {
          await publication.enable();
        } else {
          await publication.disable();
        }
      }
    }
    } finally { _applyingAudioPreference = false; }
  }

  Future<void> setCameraPublished(bool enabled) async {
    if (state != RtcConnectionState.joined || _room == null) {
      throw StateError('RTC room is not joined');
    }
    final participant = _room!.localParticipant;
    if (participant == null) {
      throw StateError('LiveKit local participant is unavailable');
    }
    await participant.setCameraEnabled(enabled);
    _publishingCamera = enabled;
  }

  Future<Map<String, dynamic>> _fetchCredentials({
    required String roomId,
    required String authToken,
  }) async {
    final request = await openBackendRequest(_httpClient, 'POST', 
      apiBase.replace(path: '/livekit/token'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(jsonEncode(<String, dynamic>{'room_id': roomId}));

    final response = await closeBackendRequest(request);
    final raw = await readBackendResponse(response);
    Map<String, dynamic> data = <String, dynamic>{};
    if (raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          data = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } on FormatException {
        throw StateError(
          raw.toLowerCase().contains('error code: 1101')
              ? 'Voice server is temporarily unavailable. Please retry.'
              : 'Voice server returned an invalid response. Please retry.',
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
    _speakingTimer?.cancel();
    _speakingLevels.dispose();
    _httpClient.close(force: true);
  }
}
