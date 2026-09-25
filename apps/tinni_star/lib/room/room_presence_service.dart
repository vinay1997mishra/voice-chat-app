import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class RoomSeatInvite {
  const RoomSeatInvite({
    required this.seatIndex,
    required this.invitedBy,
    required this.createdAt,
  });

  final int seatIndex;
  final String invitedBy;
  final DateTime createdAt;
}

class RoomPresenceMember {
  const RoomPresenceMember({
    required this.userId,
    required this.displayName,
    required this.joinedAt,
    required this.lastSeen,
    this.avatarDataUrl,
    this.flagEmoji = '',
    this.countryCode = '',
    this.seatIndex,
    this.micMuted = false,
    this.seatEmote,
    this.seatEmoteUntil,
  });

  final String userId;
  final String displayName;
  final String? avatarDataUrl;
  final String flagEmoji;
  final String countryCode;
  final int? seatIndex;
  final bool micMuted;
  final String? seatEmote;
  final DateTime? seatEmoteUntil;
  final DateTime joinedAt;
  final DateTime lastSeen;
}

class RoomPresenceService extends ChangeNotifier {
  RoomPresenceService({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinnistar-api.tinnistarchat.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  final List<RoomPresenceMember> members = <RoomPresenceMember>[];

  bool connected = false;
  bool selfMicMuted = false;
  bool selfSeatForced = false;
  int? selfForcedSeatIndex;
  RoomSeatInvite? pendingSeatInvite;
  String? lastError;

  Future<void> join({
    required String roomId,
    required String authToken,
    int? seatIndex,
  }) =>
      _post(
        '/room-presence/join',
        roomId,
        authToken,
        seatIndex: seatIndex,
      );

  Future<void> heartbeat({
    required String roomId,
    required String authToken,
    int? seatIndex,
  }) =>
      _post(
        '/room-presence/heartbeat',
        roomId,
        authToken,
        seatIndex: seatIndex,
      );

  Future<void> leave({
    required String roomId,
    required String authToken,
  }) async {
    try {
      await _post('/room-presence/leave', roomId, authToken);
    } finally {
      members.clear();
      connected = false;
      selfMicMuted = false;
      selfSeatForced = false;
      selfForcedSeatIndex = null;
      pendingSeatInvite = null;
      notifyListeners();
    }
  }

  Future<void> kick({
    required String roomId,
    required String authToken,
    required String targetUserId,
    Duration? duration,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/room-presence/kick'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, Object?>{
        'room_id': roomId,
        'target_user_id': targetUserId,
        'duration_ms': duration?.inMilliseconds,
      }),
    );
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to kick room user',
      );
    }
    _apply(data);
    notifyListeners();
  }

  Future<void> inviteToSeat({
    required String roomId,
    required String authToken,
    required String targetUserId,
    required int seatIndex,
  }) async {
    await _commandPost(
      '/room-presence/seat-invite',
      authToken,
      <String, Object>{
        'room_id': roomId,
        'target_user_id': targetUserId,
        'seat_index': seatIndex,
      },
    );
  }

  Future<void> respondSeatInvite({
    required String roomId,
    required String authToken,
    required bool accepted,
  }) async {
    final data = await _commandPost(
      '/room-presence/seat-invite/respond',
      authToken,
      <String, Object>{
        'room_id': roomId,
        'accepted': accepted,
      },
      applyResponse: false,
    );
    pendingSeatInvite = null;
    if (accepted) {
      selfSeatForced = true;
      selfForcedSeatIndex = _asInt(data['seat_index']);
    }
    notifyListeners();
  }

  Future<void> removeFromSeat({
    required String roomId,
    required String authToken,
    required String targetUserId,
  }) async {
    await _commandPost(
      '/room-presence/seat-remove',
      authToken,
      <String, Object>{
        'room_id': roomId,
        'target_user_id': targetUserId,
      },
    );
  }

    Future<void> setMute({
    required String roomId,
    required String authToken,
    required String targetUserId,
    required int seatIndex,
    required bool muted,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/room-presence/mute'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, Object>{
        'room_id': roomId,
        'target_user_id': targetUserId,
        'seat_index': seatIndex,
        'muted': muted,
      }),
    );
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to update room mute',
      );
    }
    _apply(data);
    notifyListeners();
  }

    Future<void> setEmote({
    required String roomId,
    required String authToken,
    required int seatIndex,
    required String emote,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/room-presence/emote'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, Object>{
        'room_id': roomId,
        'seat_index': seatIndex,
        'emote': emote,
      }),
    );
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to send room emote',
      );
    }
    _apply(data);
    notifyListeners();
  }

  Future<Map<String, dynamic>> _commandPost(
    String path,
    String authToken,
    Map<String, Object> payload, {
    bool applyResponse = true,
  }) async {
    final request = await _httpClient.postUrl(apiBase.replace(path: path));
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(jsonEncode(payload));
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Room action failed',
      );
    }
    if (applyResponse) {
      _apply(data);
      notifyListeners();
    }
    return data;
  }

  Future<void> refresh({
    required String roomId,
    required String authToken,
  }) async {
    try {
      final uri = apiBase.replace(
        path: '/room-presence/state',
        queryParameters: <String, String>{'room_id': roomId},
      );
      final request = await _httpClient.getUrl(uri);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $authToken',
      );
      final response = await request.close();
      final data = await _readJson(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          data['error']?.toString() ?? 'Presence HTTP ${response.statusCode}',
        );
      }
      _apply(data);
      connected = true;
      lastError = null;
    } catch (error) {
      connected = false;
      lastError = error.toString();
    }
    notifyListeners();
  }

  Future<void> _post(
    String path,
    String roomId,
    String authToken, {
    int? seatIndex,
  }) async {
    try {
      final request = await _httpClient.postUrl(apiBase.replace(path: path));
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $authToken',
      );
      request.write(
        jsonEncode(<String, Object?>{
          'room_id': roomId,
          'seat_index': seatIndex,
        }),
      );
      final response = await request.close();
      final data = await _readJson(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          data['error']?.toString() ?? 'Presence HTTP ${response.statusCode}',
        );
      }
      _apply(data);
      connected = true;
      lastError = null;
      notifyListeners();
    } catch (error) {
      connected = false;
      lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _apply(Map<String, dynamic> data) {
    selfMicMuted = data['self_mic_muted'] == true;
    selfSeatForced = data['self_seat_forced'] == true;
    selfForcedSeatIndex = selfSeatForced
        ? (data['self_forced_seat_index'] == null
            ? null
            : _asInt(data['self_forced_seat_index']))
        : null;

    final rawInvite = data['pending_seat_invite'];
    if (rawInvite is Map) {
      final createdAtMs = _asInt(rawInvite['created_at']);
      pendingSeatInvite = RoomSeatInvite(
        seatIndex: _asInt(rawInvite['seat_index']),
        invitedBy: rawInvite['invited_by']?.toString() ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      );
    } else {
      pendingSeatInvite = null;
    }

    final rawMembers = data['members'];
    if (rawMembers is! List) return;

    members
      ..clear()
      ..addAll(
        rawMembers
            .whereType<Map>()
            .map(
              (row) => RoomPresenceMember(
                userId: row['user_id']?.toString() ?? '',
                displayName: row['display_name']?.toString() ?? '',
                avatarDataUrl: row['avatar_data_url']?.toString(),
                flagEmoji: row['flag_emoji']?.toString() ?? '',
                countryCode: row['country_code']?.toString() ?? '',
                seatIndex: row['seat_index'] == null
                    ? null
                    : _asInt(row['seat_index']),
                micMuted: row['mic_muted'] == true,
                seatEmote: row['seat_emote']?.toString(),
                seatEmoteUntil: row['seat_emote_until'] == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        _asInt(row['seat_emote_until']),
                      ),
                joinedAt: DateTime.fromMillisecondsSinceEpoch(
                  _asInt(row['joined_at']),
                  isUtc: true,
                ),
                lastSeen: DateTime.fromMillisecondsSinceEpoch(
                  _asInt(row['last_seen']),
                  isUtc: true,
                ),
              ),
            )
            .where(
              (member) =>
                  member.userId.isNotEmpty && member.displayName.isNotEmpty,
            ),
      );
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    final body = await utf8.decoder.bind(response).join();
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
    _httpClient.close(force: true);
    super.dispose();
  }
}
