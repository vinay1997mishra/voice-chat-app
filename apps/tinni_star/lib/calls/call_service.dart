import 'dart:convert';
import 'dart:io';

enum CallState { idle, ringing, connected, ended, rejected }

enum CallMedia { voice, video }

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
  });

  final String id;
  final String roomId;
  final String callerId;
  final String receiverId;
  final CallMedia media;
  final CallState state;
  final String? callerName;
  final String? receiverName;

  CallSession copyWith({CallState? state}) => CallSession(
        id: id,
        roomId: roomId,
        callerId: callerId,
        receiverId: receiverId,
        media: media,
        state: state ?? this.state,
        callerName: callerName,
        receiverName: receiverName,
      );

  static CallSession fromJson(Map<String, dynamic> data) {
    final stateText = data['state']?.toString() ?? 'ringing';
    final state = switch (stateText) {
      'accepted' => CallState.connected,
      'ended' => CallState.ended,
      'rejected' => CallState.rejected,
      _ => CallState.ringing,
    };
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
    if (active != null && active!.state != CallState.ended) {
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

  void accept() {
    final call = active;
    if (call == null || call.state != CallState.ringing) return;
    active = call.copyWith(state: CallState.connected);
  }

  void reject() {
    final call = active;
    if (call == null) return;
    active = call.copyWith(state: CallState.rejected);
  }

  void end() {
    final call = active;
    if (call == null) return;
    active = call.copyWith(state: CallState.ended);
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
