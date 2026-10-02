import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../identity/owner_tag.dart';

class RoomSeatRequest {
  const RoomSeatRequest({
    required this.userId,
    required this.seatIndex,
    required this.createdAt,
  });

  final String userId;
  final int seatIndex;
  final DateTime createdAt;
}

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
    this.familyTag,
    this.hostTag,
    this.agencyName,
    this.equippedFrameId,
    this.ownerTags = const <OwnerTag>[],
    this.ownerMedals = const <OwnerTag>[],
    this.seatIndex,
    this.micMuted = false,
    this.chatBanned = false,
    this.isAdmin = false,
    this.seatEmote,
    this.seatEmoteUntil,
  });

  final String userId;
  final String displayName;
  final String? avatarDataUrl;
  final String flagEmoji;
  final String countryCode;
  final String? familyTag;
  final String? hostTag;
  final String? agencyName;
  final String? equippedFrameId;
  final List<OwnerTag> ownerTags;
  final List<OwnerTag> ownerMedals;
  final int? seatIndex;
  final bool micMuted;
  final bool chatBanned;
  final bool isAdmin;
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
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  WebSocket? _realtimeSocket;
  StreamSubscription<dynamic>? _realtimeSubscription;
  Timer? _realtimeReconnectTimer;
  Timer? _realtimeKeepAliveTimer;
  String? _realtimeRoomId;
  String? _realtimeAuthToken;
  bool _realtimeClosing = false;

  final List<RoomPresenceMember> members = <RoomPresenceMember>[];

  bool connected = false;
  String micMode = 'apply';
  bool selfMicMuted = false;
  bool selfChatBanned = false;
  bool selfSeatForced = false;
  int? selfForcedSeatIndex;
  RoomSeatInvite? pendingSeatInvite;
  final List<RoomSeatRequest> seatRequests = <RoomSeatRequest>[];
  final Set<int> lockedSeats = <int>{};
  String? lastError;

  bool get realtimeConnected =>
      _realtimeSocket?.readyState == WebSocket.open;

  Future<void> connectRealtime({
    required String roomId,
    required String authToken,
  }) async {
    _realtimeRoomId = roomId;
    _realtimeAuthToken = authToken;
    _realtimeClosing = false;
    _realtimeReconnectTimer?.cancel();
    await _openRealtimeSocket();
  }

  Future<void> disconnectRealtime() async {
    _realtimeClosing = true;
    _realtimeReconnectTimer?.cancel();
    _realtimeReconnectTimer = null;
    _realtimeKeepAliveTimer?.cancel();
    _realtimeKeepAliveTimer = null;

    final subscription = _realtimeSubscription;
    _realtimeSubscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (_) {}
    }

    final socket = _realtimeSocket;
    _realtimeSocket = null;
    if (socket != null) {
      try {
        await socket.close(WebSocketStatus.normalClosure, 'room_presence_close');
      } catch (_) {}
    }

    _realtimeRoomId = null;
    _realtimeAuthToken = null;
  }

  void syncRealtimeSeat(int? seatIndex) {
    _sendRealtime(<String, Object?>{
      'type': 'seat_state',
      'seat_index': seatIndex,
    });
  }

  Future<void> _openRealtimeSocket() async {
    if (_realtimeClosing || realtimeConnected) return;
    final roomId = _realtimeRoomId;
    final authToken = _realtimeAuthToken;
    if (roomId == null || authToken == null || authToken.isEmpty) return;

    try {
      final uri = apiBase.replace(
        scheme: apiBase.scheme == 'https' ? 'wss' : 'ws',
        path: '/room-presence/stream',
        queryParameters: <String, String>{'room_id': roomId},
      );
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: <String, dynamic>{
          HttpHeaders.authorizationHeader: 'Bearer $authToken',
        },
      );
      if (_realtimeClosing ||
          roomId != _realtimeRoomId ||
          authToken != _realtimeAuthToken) {
        await socket.close();
        return;
      }

      _realtimeSocket = socket;
      socket.pingInterval = const Duration(seconds: 20);
      _realtimeKeepAliveTimer?.cancel();
      _realtimeKeepAliveTimer = Timer.periodic(
        const Duration(seconds: 75),
        (_) => _sendRealtime(
          const <String, Object?>{'type': 'presence_keepalive'},
        ),
      );

      _realtimeSubscription = socket.listen(
        _handleRealtimeData,
        onError: (Object error) {
          lastError = error.toString();
        },
        onDone: () {
          if (identical(_realtimeSocket, socket)) {
            _realtimeSocket = null;
            _realtimeKeepAliveTimer?.cancel();
            _realtimeKeepAliveTimer = null;
            _scheduleRealtimeReconnect();
          }
        },
        cancelOnError: false,
      );
      _sendRealtime(
        const <String, Object?>{'type': 'presence_keepalive'},
      );
    } catch (error) {
      lastError = error.toString();
      _realtimeSocket = null;
      _scheduleRealtimeReconnect();
    }
  }

  void _handleRealtimeData(dynamic raw) {
    String text;
    if (raw is String) {
      text = raw;
    } else if (raw is List<int>) {
      text = utf8.decode(raw);
    } else {
      return;
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;
      final data = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (data['type'] == 'presence_error') {
        lastError = data['error']?.toString();
        return;
      }
      if (data['type'] == 'presence_state' || data['members'] is List) {
        _apply(data);
        connected = true;
        lastError = null;
        notifyListeners();
      }
    } catch (error) {
      lastError = error.toString();
    }
  }

  void _sendRealtime(Map<String, Object?> event) {
    final socket = _realtimeSocket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    try {
      socket.add(jsonEncode(event));
    } catch (_) {}
  }

  void _scheduleRealtimeReconnect() {
    if (_realtimeClosing ||
        _realtimeRoomId == null ||
        _realtimeAuthToken == null) {
      return;
    }
    _realtimeReconnectTimer?.cancel();
    _realtimeReconnectTimer = Timer(
      const Duration(seconds: 2),
      () => _openRealtimeSocket(),
    );
  }

  Future<void> join({
    required String roomId,
    required String authToken,
    int? seatIndex,
    String? familyTag,
    String? hostTag,
    String? agencyName,
    String? equippedFrameId,
  }) =>
      _post(
        '/room-presence/join',
        roomId,
        authToken,
        seatIndex: seatIndex,
        familyTag: familyTag,
        hostTag: hostTag,
        agencyName: agencyName,
        equippedFrameId: equippedFrameId,
      );

  Future<void> heartbeat({
    required String roomId,
    required String authToken,
    int? seatIndex,
    String? familyTag,
    String? hostTag,
    String? agencyName,
    String? equippedFrameId,
  }) =>
      _post(
        '/room-presence/heartbeat',
        roomId,
        authToken,
        seatIndex: seatIndex,
        familyTag: familyTag,
        hostTag: hostTag,
        agencyName: agencyName,
        equippedFrameId: equippedFrameId,
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
      micMode = 'apply';
      selfMicMuted = false;
      selfChatBanned = false;
      selfSeatForced = false;
      selfForcedSeatIndex = null;
      pendingSeatInvite = null;
      seatRequests.clear();
      lockedSeats.clear();
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

  Future<void> setAdmin({
    required String roomId,
    required String authToken,
    required String targetUserId,
    required bool enabled,
  }) async {
    await _commandPost(
      '/room-presence/admin',
      authToken,
      <String, Object>{
        'room_id': roomId,
        'target_user_id': targetUserId,
        'enabled': enabled,
      },
    );
  }

  Future<void> setChatBan({
    required String roomId,
    required String authToken,
    required String targetUserId,
    required bool banned,
  }) async {
    await _commandPost(
      '/room-presence/chat-ban',
      authToken,
      <String, Object>{
        'room_id': roomId,
        'target_user_id': targetUserId,
        'banned': banned,
      },
    );
  }

  Future<void> setMicMode({
    required String roomId,
    required String authToken,
    required String micMode,
  }) async {
    final data = await _commandPost(
      '/room-presence/mic-mode',
      authToken,
      <String, Object>{
        'room_id': roomId,
        'mic_mode': micMode,
      },
      applyResponse: false,
    );
    this.micMode = data['mic_mode']?.toString() == 'free' ? 'free' : 'apply';
    notifyListeners();
  }

  Future<void> setSeatLock({
    required String roomId,
    required String authToken,
    required int seatIndex,
    required bool locked,
  }) async {
    await _commandPost(
      '/room-presence/seat-lock',
      authToken,
      <String, Object>{'room_id': roomId, 'seat_index': seatIndex, 'locked': locked},
    );
  }

    Future<void> requestSeat({
    required String roomId,
    required String authToken,
    required int seatIndex,
  }) async {
    await _commandPost(
      '/room-presence/seat-request',
      authToken,
      <String, Object>{
        'room_id': roomId,
        'seat_index': seatIndex,
      },
    );
  }

  Future<void> resolveSeatRequest({
    required String roomId,
    required String authToken,
    required String targetUserId,
    required bool approved,
  }) async {
    await _commandPost(
      '/room-presence/seat-request/resolve',
      authToken,
      <String, Object>{
        'room_id': roomId,
        'target_user_id': targetUserId,
        'approved': approved,
      },
    );
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

  Future<Map<String, dynamic>> sendGift({
    required String roomId,
    required String authToken,
    required String giftId,
    required String giftName,
    required int quantity,
    required int unitPrice,
    required List<String> receiverIds,
  }) =>
      _commandPost(
        '/gifts/send',
        authToken,
        <String, Object>{
          'room_id': roomId,
          'gift_id': giftId,
          'gift_name': giftName,
          'quantity': quantity,
          'unit_price': unitPrice,
          'receiver_ids': receiverIds,
        },
        applyResponse: false,
      );

  Future<Map<String, dynamic>> luckyGiftState({
    required String authToken,
  }) async {
    final request = await _httpClient.getUrl(
      apiBase.replace(path: '/gifts/lucky/state'),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to load Lucky Gift state',
      );
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
    String? familyTag,
    String? hostTag,
    String? agencyName,
    String? equippedFrameId,
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
          'family_tag': familyTag,
          'host_tag': hostTag,
          'agency_name': agencyName,
          'equipped_frame_id': equippedFrameId,
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
    if (data['mic_mode'] != null) {
      micMode = data['mic_mode']?.toString() == 'free' ? 'free' : 'apply';
    }

    if (data.containsKey('self_mic_muted')) {
      selfMicMuted = data['self_mic_muted'] == true;
    }
    if (data.containsKey('self_chat_banned')) {
      selfChatBanned = data['self_chat_banned'] == true;
    }

    if (data.containsKey('self_seat_forced')) {
      selfSeatForced = data['self_seat_forced'] == true;
      selfForcedSeatIndex = selfSeatForced
          ? (data['self_forced_seat_index'] == null
              ? null
              : _asInt(data['self_forced_seat_index']))
          : null;
    }

    if (data.containsKey('pending_seat_invite')) {
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
    }

    if (data.containsKey('locked_seats')) {
      final rawLocked = data['locked_seats'];
      lockedSeats
        ..clear()
        ..addAll(rawLocked is List ? rawLocked.map(_asInt) : const <int>[]);
    }

    if (data.containsKey('seat_requests')) {
      final rawRequests = data['seat_requests'];
      seatRequests
        ..clear()
        ..addAll(
          rawRequests is List
              ? rawRequests.whereType<Map>().map(
                    (row) => RoomSeatRequest(
                      userId: row['user_id']?.toString() ?? '',
                      seatIndex: _asInt(row['seat_index']),
                      createdAt: DateTime.fromMillisecondsSinceEpoch(
                        _asInt(row['created_at']),
                      ),
                    ),
                  ).where((item) => item.userId.isNotEmpty)
              : const <RoomSeatRequest>[],
        );
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
                familyTag: row['family_tag']?.toString(),
                hostTag: row['host_tag']?.toString(),
                agencyName: row['agency_name']?.toString(),
                equippedFrameId: row['equipped_frame_id']?.toString(),
                ownerTags: row['owner_tags'] is List
                    ? (row['owner_tags'] as List)
                        .whereType<Map>()
                        .map(OwnerTag.fromMap)
                        .where((tag) => tag.name.isNotEmpty)
                        .toList(growable: false)
                    : const <OwnerTag>[],
                ownerMedals: row['owner_medals'] is List
                    ? (row['owner_medals'] as List)
                        .whereType<Map>()
                        .map(OwnerTag.fromMap)
                        .where((medal) => medal.name.isNotEmpty)
                        .toList(growable: false)
                    : const <OwnerTag>[],
                seatIndex: row['seat_index'] == null
                    ? null
                    : _asInt(row['seat_index']),
                micMuted: row['mic_muted'] == true,
                chatBanned: row['chat_banned'] == true,
                isAdmin: row['is_admin'] == true,
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
    _realtimeClosing = true;
    _realtimeReconnectTimer?.cancel();
    _realtimeKeepAliveTimer?.cancel();
    _realtimeSubscription?.cancel();
    try {
      _realtimeSocket?.close();
    } catch (_) {}
    _httpClient.close(force: true);
    super.dispose();
  }
}
