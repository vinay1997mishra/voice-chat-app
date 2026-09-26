import 'dart:convert';
import 'dart:io';

class SocialUser {
  const SocialUser({
    required this.id,
    required this.name,
    this.inRoomId,
  });

  final String id;
  final String name;
  final String? inRoomId;
}

class ChatMessage {
  const ChatMessage({
    required this.from,
    required this.to,
    required this.text,
    this.id,
    this.createdAt,
  });

  final String from;
  final String to;
  final String text;
  final String? id;
  final DateTime? createdAt;
}

class SocialService {
  SocialService({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinnistar-api.tinnistarchat.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  final Set<String> following = <String>{};
  final Set<String> friends = <String>{};
  final List<SocialUser> friendProfiles = <SocialUser>[];
  final Set<String> blocked = <String>{};
  final List<ChatMessage> directMessages = <ChatMessage>[];

  void follow(String userId) => following.add(userId);
  void unfollow(String userId) => following.remove(userId);

  Future<void> syncFollowing(String authToken) async {
    final request = await _httpClient.getUrl(
      apiBase.replace(path: '/social/following'),
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
        data['error']?.toString() ?? 'Unable to load following list',
      );
    }

    final raw = data['following'];
    following
      ..clear()
      ..addAll(
        raw is List
            ? raw.map((value) => value.toString()).where((id) => id.isNotEmpty)
            : const <String>[],
      );
  }

  Future<void> syncFriends(String authToken) async {
    final request = await _httpClient.getUrl(
      apiBase.replace(path: '/social/friends'),
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
        data['error']?.toString() ?? 'Unable to load friends list',
      );
    }

    final profiles = <SocialUser>[];
    final raw = data['friends'];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final id = item['user_id']?.toString() ?? item['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        profiles.add(
          SocialUser(
            id: id,
            name: item['display_name']?.toString() ??
                item['name']?.toString() ??
                id,
            inRoomId: item['in_room_id']?.toString(),
          ),
        );
      }
    }
    friendProfiles
      ..clear()
      ..addAll(profiles);
    friends
      ..clear()
      ..addAll(profiles.map((friend) => friend.id));
  }

  Future<void> syncBlocked(String authToken) async {
    final request = await _httpClient.getUrl(
      apiBase.replace(path: '/social/blocked'),
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
        data['error']?.toString() ?? 'Unable to load blocked users',
      );
    }

    final raw = data['blocked'];
    blocked
      ..clear()
      ..addAll(
        raw is List
            ? raw.map((value) => value.toString()).where((id) => id.isNotEmpty)
            : const <String>[],
      );
  }

  Future<bool> setBlockedRemote({
    required String authToken,
    required String targetUserId,
    required bool value,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/social/block'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, Object>{
        'target_user_id': targetUserId,
        'blocked': value,
      }),
    );
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to update block',
      );
    }

    if (value) {
      block(targetUserId);
    } else {
      unblock(targetUserId);
    }
    return value;
  }

  Future<bool> setFollowingRemote({
    required String authToken,
    required String targetUserId,
    required bool value,
  }) async {
    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/social/follow'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, Object>{
        'target_user_id': targetUserId,
        'following': value,
      }),
    );
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to update follow',
      );
    }

    if (value) {
      following.add(targetUserId);
    } else {
      following.remove(targetUserId);
    }
    return value;
  }

  void addFriend(String userId) {
    if (blocked.contains(userId)) return;
    friends.add(userId);
    if (!friendProfiles.any((friend) => friend.id == userId)) {
      friendProfiles.add(SocialUser(id: userId, name: userId));
    }
  }

  void block(String userId) {
    blocked.add(userId);
    following.remove(userId);
    friends.remove(userId);
    friendProfiles.removeWhere((friend) => friend.id == userId);
  }

  void unblock(String userId) => blocked.remove(userId);

  bool sendDirectMessage({
    required String from,
    required String to,
    required String text,
  }) {
    final value = text.trim();
    if (value.isEmpty || blocked.contains(to)) return false;
    directMessages.add(ChatMessage(from: from, to: to, text: value));
    return true;
  }

  Future<List<ChatMessage>> loadConversation({
    required String authToken,
    required String myUserId,
    required String peerUserId,
  }) async {
    final request = await _httpClient.getUrl(
      apiBase.replace(
        path: '/messages',
        queryParameters: <String, String>{
          'peer_user_id': peerUserId,
          'limit': '300',
        },
      ),
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
        data['error']?.toString() ?? 'Unable to load messages',
      );
    }

    final values = <ChatMessage>[];
    final raw = data['messages'];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final from = item['from']?.toString() ?? '';
        final to = item['to']?.toString() ?? '';
        final text = item['text']?.toString() ?? '';
        if (from.isEmpty || to.isEmpty || text.isEmpty) continue;
        final createdAtMs = _asInt(item['created_at']);
        values.add(
          ChatMessage(
            id: item['id']?.toString(),
            from: from,
            to: to,
            text: text,
            createdAt: createdAtMs > 0
                ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
                : null,
          ),
        );
      }
    }

    directMessages.removeWhere(
      (message) =>
          (message.from == myUserId && message.to == peerUserId) ||
          (message.from == peerUserId && message.to == myUserId),
    );
    directMessages.addAll(values);
    return values;
  }

  Future<ChatMessage> sendDirectMessageRemote({
    required String authToken,
    required String from,
    required String to,
    required String text,
  }) async {
    final value = text.trim();
    if (value.isEmpty) throw StateError('Message cannot be empty');
    if (blocked.contains(to)) throw StateError('User is blocked');

    final request = await _httpClient.postUrl(
      apiBase.replace(path: '/messages'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, Object>{
        'to_user_id': to,
        'text': value,
      }),
    );
    final response = await request.close();
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to send message',
      );
    }

    final raw = data['message'];
    if (raw is! Map) throw StateError('Server returned invalid message');
    final createdAtMs = _asInt(raw['created_at']);
    final message = ChatMessage(
      id: raw['id']?.toString(),
      from: raw['from']?.toString() ?? from,
      to: raw['to']?.toString() ?? to,
      text: raw['text']?.toString() ?? value,
      createdAt: createdAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now(),
    );
    directMessages.add(message);
    return message;
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

  void dispose() => _httpClient.close(force: true);
}
