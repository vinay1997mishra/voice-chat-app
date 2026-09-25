import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class RoomPresenceMember {
  const RoomPresenceMember({
    required this.userId,
    required this.displayName,
    required this.joinedAt,
    required this.lastSeen,
    this.avatarDataUrl,
    this.flagEmoji = '',
    this.countryCode = '',
  });

  final String userId;
  final String displayName;
  final String? avatarDataUrl;
  final String flagEmoji;
  final String countryCode;
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
  String? lastError;

  Future<void> join({
    required String roomId,
    required String authToken,
  }) =>
      _post('/room-presence/join', roomId, authToken);

  Future<void> heartbeat({
    required String roomId,
    required String authToken,
  }) =>
      _post('/room-presence/heartbeat', roomId, authToken);

  Future<void> leave({
    required String roomId,
    required String authToken,
  }) async {
    try {
      await _post('/room-presence/leave', roomId, authToken);
    } finally {
      members.clear();
      connected = false;
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
    String authToken,
  ) async {
    try {
      final request = await _httpClient.postUrl(apiBase.replace(path: path));
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $authToken',
      );
      request.write(jsonEncode(<String, Object>{'room_id': roomId}));
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
