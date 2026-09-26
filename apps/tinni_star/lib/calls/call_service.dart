import 'dart:convert';
import 'dart:io';

enum CallState { idle, ringing, connected, ended, rejected }

enum CallMedia { voice, video }

class CallVerificationStatus {
  const CallVerificationStatus({
    required this.verified,
    required this.status,
    required this.gender,
    required this.randomCallEligible,
    required this.receiverEarningEligible,
    this.verifiedAt,
    this.revokedAt,
  });

  final bool verified;
  final String status;
  final String gender;
  final bool randomCallEligible;
  final bool receiverEarningEligible;
  final int? verifiedAt;
  final int? revokedAt;

  static CallVerificationStatus fromJson(Map<String, dynamic> data) {
    int? asNullableInt(Object? value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    return CallVerificationStatus(
      verified: data['verified'] == true,
      status: data['status']?.toString() ?? 'unverified',
      gender: data['gender']?.toString() ?? '',
      randomCallEligible: data['random_call_eligible'] == true,
      receiverEarningEligible:
          data['eligible_for_receiver_earnings'] == true,
      verifiedAt: asNullableInt(data['verified_at']),
      revokedAt: asNullableInt(data['revoked_at']),
    );
  }
}

class CallSession {
  const CallSession({
    required this.id,
    required this.roomId,
    required this.callerId,
    required this.receiverId,
    required this.media,
    required this.state,
    this.callerName,
    this.receiverName,
    this.callKind = 'direct',
    this.costCoinsPerMinute = 0,
    this.receiverDiamondsPerMinute = 0,
    this.receiverEarningEligible = false,
    this.callerBalanceCoins,
    this.receiverBalanceDiamonds,
    this.endReason,
    this.receiverVerification,
  });

  final String id;
  final String roomId;
  final String callerId;
  final String receiverId;
  final CallMedia media;
  final CallState state;
  final String? callerName;
  final String? receiverName;
  final String callKind;
  final int costCoinsPerMinute;
  final int receiverDiamondsPerMinute;
  final bool receiverEarningEligible;
  final int? callerBalanceCoins;
  final int? receiverBalanceDiamonds;
  final String? endReason;
  final CallVerificationStatus? receiverVerification;

  bool get isRandom => callKind == 'random';

  CallSession copyWith({CallState? state}) => CallSession(
        id: id,
        roomId: roomId,
        callerId: callerId,
        receiverId: receiverId,
        media: media,
        state: state ?? this.state,
        callerName: callerName,
        receiverName: receiverName,
        callKind: callKind,
        costCoinsPerMinute: costCoinsPerMinute,
        receiverDiamondsPerMinute: receiverDiamondsPerMinute,
        receiverEarningEligible: receiverEarningEligible,
        callerBalanceCoins: callerBalanceCoins,
        receiverBalanceDiamonds: receiverBalanceDiamonds,
        endReason: endReason,
        receiverVerification: receiverVerification,
      );

  static int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static int _intValue(Object? value) => _intOrNull(value) ?? 0;

  static Map<String, dynamic> _stringMap(Map source) =>
      source.map((key, value) => MapEntry(key.toString(), value));

  static CallSession fromJson(Map<String, dynamic> data) {
    final stateText = data['state']?.toString() ?? 'ringing';
    final state = switch (stateText) {
      'accepted' => CallState.connected,
      'ended' => CallState.ended,
      'rejected' => CallState.rejected,
      _ => CallState.ringing,
    };
    final verificationRaw = data['receiver_verification'];
    return CallSession(
      id: data['id']?.toString() ?? '',
      roomId: data['room_id']?.toString() ?? '',
      callerId: data['caller_id']?.toString() ?? '',
      receiverId: data['receiver_id']?.toString() ?? '',
      callerName: data['caller_name']?.toString(),
      receiverName: data['receiver_name']?.toString(),
      media: data['media']?.toString() == 'video'
          ? CallMedia.video
          : CallMedia.voice,
      state: state,
      callKind: data['call_kind']?.toString() ?? 'direct',
      costCoinsPerMinute: _intValue(data['cost_coins_per_minute']),
      receiverDiamondsPerMinute:
          _intValue(data['receiver_diamonds_per_minute']),
      receiverEarningEligible: data['receiver_earning_eligible'] == true,
      callerBalanceCoins: _intOrNull(data['caller_balance_coins']),
      receiverBalanceDiamonds:
          _intOrNull(data['receiver_balance_diamonds']),
      endReason: data['end_reason']?.toString(),
      receiverVerification: verificationRaw is Map
          ? CallVerificationStatus.fromJson(_stringMap(verificationRaw))
          : null,
    );
  }
}

class CallService {
  CallService({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinnistar-api.tinnistarchat.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  bool friendsOnly = true;
  CallSession? active;

  CallSession initiate({
    required String callerId,
    required String receiverId,
    required CallMedia media,
    required bool isFriend,
  }) {
    if (friendsOnly && !isFriend) {
      throw StateError('Calls are limited to friends');
    }
    if (active != null &&
        active!.state != CallState.ended &&
        active!.state != CallState.rejected) {
      throw StateError('Another call is active');
    }
    active = CallSession(
      id: 'local-' + DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: 'local-call',
      callerId: callerId,
      receiverId: receiverId,
      media: media,
      state: CallState.ringing,
    );
    return active!;
  }

  Future<CallSession> startRemote({
    required String authToken,
    required String receiverId,
    CallMedia media = CallMedia.voice,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/calls',
      authToken: authToken,
      body: <String, Object?>{
        'receiver_id': receiverId,
        'media': media == CallMedia.video ? 'video' : 'voice',
      },
    );
    final raw = data['call'];
    if (raw is! Map) throw StateError('Server returned an invalid call');
    active = CallSession.fromJson(_stringMap(raw));
    return active!;
  }

  Future<CallSession> startRandomRemote({
    required String authToken,
    required String gender,
    CallMedia media = CallMedia.voice,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/calls/random',
      authToken: authToken,
      body: <String, Object?>{
        'gender': gender,
        'media': media == CallMedia.video ? 'video' : 'voice',
      },
    );
    final raw = data['call'];
    if (raw is! Map) throw StateError('Server returned an invalid call');
    active = CallSession.fromJson(_stringMap(raw));
    return active!;
  }

  Future<CallVerificationStatus> verificationStatus({
    required String authToken,
  }) async {
    final data = await _request(
      method: 'GET',
      path: '/calls/verification/status',
      authToken: authToken,
    );
    final raw = data['verification'];
    if (raw is! Map) {
      throw StateError('Server returned an invalid verification status');
    }
    return CallVerificationStatus.fromJson(_stringMap(raw));
  }

  Future<Map<String, dynamic>> submitVerification({
    required String authToken,
    required List<String> photos,
    required bool systemPassed,
    required Map<String, Object?> systemDetails,
  }) async {
    return _request(
      method: 'POST',
      path: '/calls/verification/submit',
      authToken: authToken,
      body: <String, Object?>{
        'photos': photos,
        'system_passed': systemPassed,
        'system_details': systemDetails,
      },
    );
  }

  Future<CallSession> statusRemote({
    required String authToken,
    required String callId,
  }) async {
    final data = await _request(
      method: 'GET',
      path: '/calls/status?call_id=' + Uri.encodeQueryComponent(callId),
      authToken: authToken,
    );
    final raw = data['call'];
    if (raw is! Map) throw StateError('Server returned an invalid call');
    active = CallSession.fromJson(_stringMap(raw));
    return active!;
  }

  Future<CallSession?> incomingRemote({
    required String authToken,
  }) async {
    final data = await _request(
      method: 'GET',
      path: '/calls/incoming',
      authToken: authToken,
    );
    final raw = data['call'];
    if (raw == null) return null;
    if (raw is! Map) throw StateError('Server returned an invalid call');
    final call = CallSession.fromJson(_stringMap(raw));
    active = call;
    return call;
  }

  Future<CallSession> respondRemote({
    required String authToken,
    required String callId,
    required bool accept,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/calls/respond',
      authToken: authToken,
      body: <String, Object?>{
        'call_id': callId,
        'accept': accept,
      },
    );
    final raw = data['call'];
    if (raw is! Map) throw StateError('Server returned an invalid call');
    active = CallSession.fromJson(_stringMap(raw));
    return active!;
  }

  Future<CallSession> endRemote({
    required String authToken,
    required String callId,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/calls/end',
      authToken: authToken,
      body: <String, Object?>{'call_id': callId},
    );
    final raw = data['call'];
    if (raw is! Map) throw StateError('Server returned an invalid call');
    active = CallSession.fromJson(_stringMap(raw));
    return active!;
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    required String authToken,
    Map<String, Object?>? body,
  }) async {
    final rawUri = Uri.parse(path);
    final uri = apiBase.replace(
      path: rawUri.path,
      query: rawUri.hasQuery ? rawUri.query : null,
    );
    final request = method == 'GET'
        ? await _httpClient.getUrl(uri)
        : await _httpClient.postUrl(uri);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    final decoded = raw.trim().isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map ? _stringMap(decoded) : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Call request failed',
      );
    }
    return data;
  }

  static Map<String, dynamic> _stringMap(Map source) =>
      source.map((key, value) => MapEntry(key.toString(), value));

  void dispose() => _httpClient.close(force: true);
}
