import 'dart:async';
import '../infra/request_budget.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'local_chat_store.dart';

import '../infra/backend_http.dart';

import 'package:flutter/foundation.dart';

class SocialUser {
  const SocialUser({
    required this.id,
    required this.name,
    this.inRoomId,
    this.avatarDataUrl,
  });

  final String id;
  final String name;
  final String? inRoomId;
  final String? avatarDataUrl;
}

class ChatMessage {
  const ChatMessage({
    required this.from,
    required this.to,
    required this.text,
    this.id,
    this.createdAt,
    this.seenAt,
    this.kind = 'text',
    this.mediaUrl,
  });

  final String from;
  final String to;
  final String text;
  final String? id;
  final DateTime? createdAt;
  final DateTime? seenAt;
  final String kind;
  final String? mediaUrl;

  bool get isImage => kind == 'image' && (mediaUrl?.isNotEmpty ?? false);
}

class MessageThread {
  const MessageThread({
    required this.userId,
    required this.displayName,
    required this.isFriend,
    this.avatarDataUrl,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String userId;
  final String displayName;
  final bool isFriend;
  final String? avatarDataUrl;
  final ChatMessage? lastMessage;
  final int unreadCount;
}

class SocialService {
  SocialService({
    Uri? apiBase,
    HttpClient? httpClient,
    this.localHistory,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;
  final LocalChatStore? localHistory;
  String? _localAccount;
  String? _localUserId;
  Future<void> _historyReady = Future<void>.value();
  Future<void> _photoQueue = Future<void>.value();
  bool _saveRunning = false;
  bool _saveDirty = false;
  Future<void>? _saveTask;
  final Map<String, Future<Uint8List?>> _photoReads = {};

  Future<void> bindLocalAccount(String? email, String? userId) {
    final account = email == null || userId == null
        ? null : '${apiBase.origin}|${email.trim().isEmpty ? userId : email.trim().toLowerCase()}';
    if (account == _localAccount && userId == _localUserId) return _historyReady;
    final previous = _localAccount;
    _localAccount = account;
    _localUserId = userId;
    _photoReads.clear();
    if (previous != null && previous != account) {
      directMessages.clear();
      messageThreads.clear();
      following.clear();
      friends.clear();
      friendProfiles.clear();
      blocked.clear();
      _setUnreadMessages(0);
    }
    final history = localHistory;
    if (account == null || history == null) return _historyReady;
    _historyReady = () async {
      try {
        final data = await history.load(account);
        if (_localAccount != account || _localUserId != userId) return;
        final oldUserId = data['user_id']?.toString();
        final existing = List<ChatMessage>.of(directMessages);
        final cached = (data['messages'] as List? ?? const [])
            .whereType<Map>().map((row) => _cachedMessage(row, oldUserId, userId!));
        final rawThreads = data['threads'];
        if (rawThreads is List) {
          for (final row in rawThreads.whereType<Map>()) {
            final peer = row['user_id']?.toString() ?? '';
            if (peer.isEmpty || messageThreads.any((thread) => thread.userId == peer)) continue;
            messageThreads.add(MessageThread(
              userId: peer, displayName: row['display_name']?.toString() ?? peer,
              isFriend: false, avatarDataUrl: row['avatar_data_url']?.toString(),
              lastMessage: row['last_message'] is Map
                  ? _cachedMessage(row['last_message'] as Map, oldUserId, userId!) : null,
            ));
          }
        }
        _mergeMessages([...cached, ...existing.map((message) =>
            _cachedMessage(_messageJson(message), oldUserId, userId!))]);
      } catch (error) {
        debugPrint('Local chat history could not be loaded: $error');
      }
    }();
    return _historyReady;
  }

  ChatMessage _cachedMessage(Map row, String? oldUserId, String userId) {
    String participant(dynamic value) => value?.toString() == oldUserId
        ? userId : value?.toString() ?? '';
    final created = _asInt(row['created_at']), seen = _asInt(row['seen_at']);
    return ChatMessage(id: row['id']?.toString(),
      from: participant(row['from']), to: participant(row['to']),
      text: row['text']?.toString() ?? '', kind: row['message_kind']?.toString() ?? 'text',
      mediaUrl: row['media_url']?.toString(),
      createdAt: created > 0 ? DateTime.fromMillisecondsSinceEpoch(created) : null,
      seenAt: seen > 0 ? DateTime.fromMillisecondsSinceEpoch(seen) : null);
  }

  Map<String, dynamic> _messageJson(ChatMessage message) => {
    'id': message.id, 'from': message.from, 'to': message.to, 'text': message.text,
    'message_kind': message.kind, 'media_url': message.mediaUrl,
    'created_at': message.createdAt?.millisecondsSinceEpoch,
    'seen_at': message.seenAt?.millisecondsSinceEpoch,
  };

  void _mergeMessages(Iterable<ChatMessage> values) {
    final merged = <String, ChatMessage>{};
    for (final message in [...directMessages, ...values]) {
      final key = message.id ?? '${message.from}|${message.to}|${message.createdAt}|${message.text}';
      merged[key] = message;
    }
    directMessages
      ..clear()
      ..addAll(merged.values);
    directMessages.sort((a, b) =>
        (a.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(b.createdAt?.millisecondsSinceEpoch ?? 0));
    final myId = _localUserId;
    if (myId != null) {
      for (final message in directMessages) {
        final peer = message.from == myId ? message.to : message.from;
        final index = messageThreads.indexWhere((thread) => thread.userId == peer);
        final old = index < 0 ? null : messageThreads[index];
        if (old != null && (old.lastMessage?.createdAt?.millisecondsSinceEpoch ?? 0) >
            (message.createdAt?.millisecondsSinceEpoch ?? 0)) { continue; }
        final next = MessageThread(userId: peer,
          displayName: old?.displayName ?? peer, isFriend: old?.isFriend ?? friends.contains(peer),
          avatarDataUrl: old?.avatarDataUrl, unreadCount: old?.unreadCount ?? 0, lastMessage: message);
        if (index < 0) { messageThreads.add(next); } else { messageThreads[index] = next; }
      }
    }
  }

  Future<void> flushLocalHistory() async {
    await _saveTask;
    await _writeLocalHistory();
  }

  Future<void> _writeLocalHistory() async {
    await _historyReady;
    final account = _localAccount, store = localHistory;
    if (account == null || store == null) return;
    await store.save(account, {
      'version': 1, 'user_id': _localUserId,
      'messages': directMessages.map(_messageJson).toList(),
      'threads': messageThreads.map((thread) => {
        'user_id': thread.userId, 'display_name': thread.displayName,
        'avatar_data_url': thread.avatarDataUrl,
        'last_message': thread.lastMessage == null ? null : _messageJson(thread.lastMessage!),
      }).toList(),
    });
  }

  void _persistHistory() {
    _saveDirty = true;
    if (_saveRunning) return;
    _saveRunning = true;
    _saveTask = () async {
      try {
        while (_saveDirty) {
          _saveDirty = false;
          await _writeLocalHistory();
        }
      } catch (error) {
        debugPrint('Local chat history could not be saved: $error');
      } finally { _saveRunning = false; }
    }();
    unawaited(_saveTask!);
  }

  void _prefetchPhotos(Iterable<ChatMessage> messages, String authToken) {
    if (localHistory == null || _localAccount == null) return;
    for (final message in messages.where((message) => message.isImage)) {
      unawaited(loadMessagePhoto(authToken: authToken, message: message));
    }
  }

  Future<Uint8List?> loadMessagePhoto({
    required String authToken, required ChatMessage message,
  }) {
    final account = _localAccount, id = message.id ?? message.mediaUrl ?? '';
    final key = '${account ?? ''}|$id';
    return _photoReads.putIfAbsent(key, () {
      final operation = _photoQueue.then<Uint8List?>((_) async {
        try {
          final local = account == null ? null : await localHistory?.readPhoto(account, id);
          if (local != null) return local;
          if (account != _localAccount) return null;
          final url = Uri.tryParse(message.mediaUrl ?? '');
          if (url == null || url.origin != apiBase.origin ||
              !url.path.startsWith('/message-media/')) return null;
          final request = await openBackendRequest(_httpClient, 'GET', url);
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
          final response = await closeBackendRequest(request);
          if (response.statusCode != 200) { await response.drain<void>(); return null; }
          final bytes = BytesBuilder(copy: false);
          await for (final chunk in response.timeout(const Duration(seconds: 20))) {
            bytes.add(chunk);
            if (bytes.length > 4000000) { throw StateError('Chat photo exceeds size limit'); }
          }
          final result = bytes.takeBytes();
          if (result.isEmpty) return null;
          if (account != null && localHistory != null) {
            await localHistory!.savePhoto(account, id, result);
          }
          return result;
        } catch (_) { return null; }
      });
      _photoQueue = operation.then<void>((_) {});
      unawaited(operation.whenComplete(() => _photoReads.remove(key)));
      return operation;
    });
  }


  final Set<String> following = <String>{};
  final Set<String> friends = <String>{};
  final List<SocialUser> friendProfiles = <SocialUser>[];
  final Set<String> blocked = <String>{};
  final List<ChatMessage> directMessages = <ChatMessage>[];
  final List<MessageThread> messageThreads = <MessageThread>[];

  final ValueNotifier<int> unreadMessages = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, dynamic>?> messageEvents =
      ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<Map<String, dynamic>?> roomEvents =
      ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<Map<String, dynamic>?> accountEvents =
      ValueNotifier<Map<String, dynamic>?>(null);
  Timer? _accountRead;
  bool _roomsWanted = false;
  void watchRooms(bool enabled) {
    _roomsWanted = enabled;
    if (messageEventsConnected) {
      _messageSocket!.add(jsonEncode({'type': 'subscribe_rooms', 'enabled': enabled}));
    }
  }

  bool get messageEventsConnected => _messageSocket?.readyState == WebSocket.open;
  int _messageReconnectFailures = 0;
  WebSocket? _messageSocket;
  StreamSubscription<dynamic>? _messageSocketSubscription;
  Timer? _messageReconnectTimer;
  Timer? _messageConnectTimeout;
  Completer<WebSocket>? _pendingMessageConnection;
  String? _messageAuthToken;
  bool _messageEventsWanted = false;
  int _messageEventConsumers = 0;

  void retainMessageEvents() => _messageEventConsumers++;

  Future<void> releaseMessageEvents() async {
    if (_messageEventConsumers > 0) _messageEventConsumers--;
    if (_messageEventConsumers == 0) await disconnectMessageEvents();
  }

  bool _messageSocketConnecting = false;

  int get totalUnreadMessages => unreadMessages.value;

  void _setUnreadMessages(int value) {
    final next = value < 0 ? 0 : value;
    if (unreadMessages.value == next) return;
    unreadMessages.value = next;
  }

  Future<void> connectMessageEvents(String authToken) async {
    final token = authToken.trim();
    if (token.isEmpty) return;
    if (_messageAuthToken != null && _messageAuthToken != token) {
      await disconnectMessageEvents();
    }
    _messageEventsWanted = true;
    _messageAuthToken = token;
    await _openMessageSocket();
  }

  Future<void> disconnectMessageEvents() async {
    _accountRead?.cancel();
    _accountRead = null;
    _messageEventsWanted = false;
    _messageAuthToken = null;
    _messageConnectTimeout?.cancel();
    _messageConnectTimeout = null;
    final pending = _pendingMessageConnection;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Message connection cancelled'));
    }
    _pendingMessageConnection = null;
    _messageReconnectTimer?.cancel();
    _messageReconnectTimer = null;
    final subscription = _messageSocketSubscription;
    _messageSocketSubscription = null;
    await subscription?.cancel();
    final socket = _messageSocket;
    _messageSocket = null;
    try {
      await socket?.close();
    } catch (_) {}
  }

  Future<void> _openMessageSocket() async {
    if (!_messageEventsWanted || _messageSocketConnecting) return;
    final token = _messageAuthToken;
    if (token == null || token.isEmpty) return;
    final existing = _messageSocket;
    if (existing != null && existing.readyState == WebSocket.open) return;

    _messageSocketConnecting = true;
    try {
      final socketUri = apiBase.replace(
        scheme: apiBase.scheme == 'https' ? 'wss' : 'ws',
        path: '/messages/live',
        query: null,
      );
      final pending = Completer<WebSocket>();
      _pendingMessageConnection = pending;
      _messageConnectTimeout = Timer(const Duration(seconds: 15), () {
        if (!pending.isCompleted) {
          pending.completeError(TimeoutException('Message connection timed out'));
        }
      });
      unawaited(WebSocket.connect(
        socketUri.toString(),
        headers: <String, dynamic>{
          HttpHeaders.authorizationHeader: 'Bearer $token',
        },
      ).then<void>((socket) {
        if (pending.isCompleted) {
          unawaited(socket.close());
        } else {
          pending.complete(socket);
        }
      }, onError: (Object error, StackTrace stack) {
        if (!pending.isCompleted) pending.completeError(error, stack);
      }));
      final socket = await pending.future;
      _messageConnectTimeout?.cancel();
      _messageConnectTimeout = null;
      _pendingMessageConnection = null;
      if (!_messageEventsWanted || token != _messageAuthToken) {
        await socket.close();
        return;
      }
      socket.pingInterval = const Duration(seconds: 60);
      _messageSocket = socket;
      if (_roomsWanted) socket.add(jsonEncode({'type': 'subscribe_rooms', 'enabled': true}));
      _messageSocketSubscription = socket.listen(
        _handleMessageSocketData,
        onDone: _handleMessageSocketClosed,
        onError: (_) => _handleMessageSocketClosed(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleMessageSocketReconnect();
    } finally {
      _messageConnectTimeout?.cancel();
      _messageConnectTimeout = null;
      _pendingMessageConnection = null;
      _messageSocketConnecting = false;
    }
  }

  void _handleMessageSocketData(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final event = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      _messageReconnectFailures = 0;
      if (event['type'] == 'account_state') {
        accountEvents.value = Map<String, dynamic>.from(event);
        return;
      }
      if (event['type'] == 'account_changed') {
        _accountRead ??= Timer(const Duration(milliseconds: 250), () {
          _accountRead = null;
          if (messageEventsConnected) _messageSocket!.add(jsonEncode({'type': 'account_state'}));
        });
        return;
      }
      if (event['type'] == 'country_ribbon' || event['type'] == 'ribbons_snapshot' ||
          event['type'] == 'rooms_snapshot' || event['type'] == 'room_updated') {
        roomEvents.value = Map<String, dynamic>.from(event);
        return;
      }
      final count = event['unread_count'];
      if (count is num) {
        _setUnreadMessages(count.toInt());
      } else if (count != null) {
        _setUnreadMessages(int.tryParse(count.toString()) ?? 0);
      }
      if (event['type'] == 'message_received' && event['message'] is Map) {
        applyMessageEvent(Map<String, dynamic>.from(event['message'] as Map));
      }
      messageEvents.value = Map<String, dynamic>.from(event);
    } catch (_) {}
  }

  void acknowledgeGameResult(Map<String, dynamic> result) {
    if (messageEventsConnected) {
      _messageSocket!.add(jsonEncode({
        'type': 'game_result_seen', 'game_key': result['game_key'], 'round_id': result['round_id'],
      }));
    }
  }

  void markLiveConversationSeen(String peerUserId) {
    if (messageEventsConnected) {
      _messageSocket!.add(jsonEncode({'type': 'messages_seen', 'peer_user_id': peerUserId}));
    }
  }

  void applyMessageEvent(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final from = row['from']?.toString() ?? '';
    final to = row['to']?.toString() ?? '';
    if (id == null || id.isEmpty || from.isEmpty || to.isEmpty) return;
    final message = ChatMessage(
      id: id, from: from, to: to, text: row['text']?.toString() ?? '',
      kind: row['message_kind']?.toString() ?? 'text',
      mediaUrl: row['media_url']?.toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch((row['created_at'] as num?)?.toInt() ?? 0),
    );
    if (directMessages.any((item) => item.id == id)) return;
    _mergeMessages([message]);
    if (_messageAuthToken != null) _prefetchPhotos([message], _messageAuthToken!);
    final index = messageThreads.indexWhere((thread) => thread.userId == from);
    final old = index < 0 ? null : messageThreads.removeAt(index);
    messageThreads.insert(0, MessageThread(
      userId: from, displayName: old?.displayName ?? row['from_name']?.toString() ?? from,
      avatarDataUrl: old?.avatarDataUrl, isFriend: old?.isFriend ?? friends.contains(from),
      lastMessage: message, unreadCount: (old?.unreadCount ?? 0) + 1,
    ));
    _persistHistory();
  }

  void _handleMessageSocketClosed() {
    _messageSocket = null;
    _messageSocketSubscription = null;
    _scheduleMessageSocketReconnect();
  }

  void _scheduleMessageSocketReconnect() {
    if (!_messageEventsWanted || _messageReconnectTimer != null) return;
    _messageReconnectTimer = Timer(RequestBudget.reconnectDelay(_messageReconnectFailures++), () {
      _messageReconnectTimer = null;
      _openMessageSocket();
    });
  }

  void follow(String userId) => following.add(userId);
  void unfollow(String userId) => following.remove(userId);

  Future<void> syncFollowing(String authToken) async {
    final request = await openBackendRequest(_httpClient, 'GET', 
      apiBase.replace(path: '/social/following'),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await closeBackendRequest(request);
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
    final request = await openBackendRequest(_httpClient, 'GET', 
      apiBase.replace(path: '/social/friends'),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await closeBackendRequest(request);
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
            avatarDataUrl: item['avatar_data_url']?.toString(),
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
    final request = await openBackendRequest(_httpClient, 'GET', 
      apiBase.replace(path: '/social/blocked'),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await closeBackendRequest(request);
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
    final request = await openBackendRequest(_httpClient, 'POST', 
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
    final response = await closeBackendRequest(request);
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
    final request = await openBackendRequest(_httpClient, 'POST', 
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
    final response = await closeBackendRequest(request);
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
    await syncFriends(authToken);
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
    if (value.isEmpty || blocked.contains(to) || !friends.contains(to)) {
      return false;
    }
    directMessages.add(ChatMessage(from: from, to: to, text: value));
    return true;
  }

  Future<List<MessageThread>> syncInbox(String authToken) async {
    await _historyReady;
    final localAccount = _localAccount;
    final request = await openBackendRequest(_httpClient, 'GET', 
      apiBase.replace(path: '/messages/inbox'),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to load inbox',
      );
    }

    final values = <MessageThread>[];
    final raw = data['threads'];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final userId = item['user_id']?.toString() ?? '';
        if (userId.isEmpty) continue;
        ChatMessage? lastMessage;
        final rawMessage = item['last_message'];
        if (rawMessage is Map) {
          final from = rawMessage['from']?.toString() ?? '';
          final to = rawMessage['to']?.toString() ?? '';
          final text = rawMessage['text']?.toString() ?? '';
          final kind = rawMessage['message_kind']?.toString() ?? 'text';
          final mediaUrl = rawMessage['media_url']?.toString();
          if (from.isNotEmpty &&
              to.isNotEmpty &&
              (text.isNotEmpty ||
                  (kind == 'image' && (mediaUrl?.isNotEmpty ?? false)))) {
            final createdAtMs = _asInt(rawMessage['created_at']);
            final seenAtMs = _asInt(rawMessage['seen_at']);
            lastMessage = ChatMessage(
              id: rawMessage['id']?.toString(),
              from: from,
              to: to,
              text: text,
              kind: kind,
              mediaUrl: mediaUrl,
              createdAt: createdAtMs > 0
                  ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
                  : null,
              seenAt: seenAtMs > 0
                  ? DateTime.fromMillisecondsSinceEpoch(seenAtMs)
                  : null,
            );
          }
        }
        values.add(
          MessageThread(
            userId: userId,
            displayName:
                item['display_name']?.toString() ?? userId,
            avatarDataUrl: item['avatar_data_url']?.toString(),
            isFriend: item['is_friend'] == true,
            lastMessage: lastMessage,
            unreadCount: _asInt(item['unread_count']),
          ),
        );
      }
    }

    if (localAccount != _localAccount) throw StateError('Account changed');
    final localOnly = messageThreads.where((thread) =>
        !values.any((remote) => remote.userId == thread.userId)).map((thread) =>
        MessageThread(userId: thread.userId, displayName: thread.displayName,
          isFriend: false, avatarDataUrl: thread.avatarDataUrl, lastMessage: thread.lastMessage));
    final combined = [...values, ...localOnly];
    messageThreads
      ..clear()
      ..addAll(combined);
    _mergeMessages(values.map((thread) => thread.lastMessage).whereType<ChatMessage>());
    _persistHistory();
    _prefetchPhotos(values.map((thread) => thread.lastMessage).whereType<ChatMessage>(), authToken);
    _setUnreadMessages(
      values.fold<int>(
        0,
        (total, thread) => total + thread.unreadCount,
      ),
    );

    final friendThreads = values.where((thread) => thread.isFriend).toList();
    friendProfiles
      ..clear()
      ..addAll(
        friendThreads.map(
          (thread) => SocialUser(
            id: thread.userId,
            name: thread.displayName,
            avatarDataUrl: thread.avatarDataUrl,
          ),
        ),
      );
    friends
      ..clear()
      ..addAll(friendThreads.map((thread) => thread.userId));

    return combined;
  }

  Future<List<ChatMessage>> loadConversation({
    required String authToken,
    required String myUserId,
    required String peerUserId,
  }) async {
    await _historyReady;
    final localAccount = _localAccount;
    final request = await openBackendRequest(_httpClient, 'GET', 
      apiBase.replace(
        path: '/messages',
        queryParameters: <String, String>{
          'peer_user_id': peerUserId,
          'limit': '500',
        },
      ),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await closeBackendRequest(request);
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
        final kind = item['message_kind']?.toString() ?? 'text';
        final mediaUrl = item['media_url']?.toString();
        if (from.isEmpty || to.isEmpty) continue;
        if (kind != 'image' && text.isEmpty) continue;
        if (kind == 'image' && !(mediaUrl?.isNotEmpty ?? false)) continue;
        final createdAtMs = _asInt(item['created_at']);
        final seenAtMs = _asInt(item['seen_at']);
        values.add(
          ChatMessage(
            id: item['id']?.toString(),
            from: from,
            to: to,
            text: text,
            kind: kind,
            mediaUrl: mediaUrl,
            createdAt: createdAtMs > 0
                ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
                : null,
            seenAt: seenAtMs > 0
                ? DateTime.fromMillisecondsSinceEpoch(seenAtMs)
                : null,
          ),
        );
      }
    }

    if (localAccount != _localAccount) throw StateError('Account changed');
    _mergeMessages(values);
    _persistHistory();
    _prefetchPhotos(values, authToken);
    return directMessages.where((message) =>
        (message.from == myUserId && message.to == peerUserId) ||
        (message.from == peerUserId && message.to == myUserId)).toList();
  }

  Future<ChatMessage> sendDirectMessageRemote({
    required String authToken,
    required String from,
    required String to,
    required String text,
  }) async {
    await _historyReady;
    final sendingAccount = _localAccount;
    final value = text.trim();
    if (value.isEmpty) throw StateError('Message cannot be empty');
    if (!friends.contains(to)) {
      throw StateError(
        'Both users must follow each other before messaging.',
      );
    }
    if (blocked.contains(to)) throw StateError('User is blocked');

    final request = await openBackendRequest(_httpClient, 'POST', 
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
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to send message',
      );
    }

    if (sendingAccount != _localAccount) throw StateError('Account changed');
    final raw = data['message'];
    if (raw is! Map) throw StateError('Server returned invalid message');
    final createdAtMs = _asInt(raw['created_at']);
    final seenAtMs = _asInt(raw['seen_at']);
    final message = ChatMessage(
      id: raw['id']?.toString(),
      from: raw['from']?.toString() ?? from,
      to: raw['to']?.toString() ?? to,
      text: raw['text']?.toString() ?? value,
      kind: raw['message_kind']?.toString() ?? 'text',
      mediaUrl: raw['media_url']?.toString(),
      createdAt: createdAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now(),
      seenAt: seenAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(seenAtMs)
          : null,
    );
    _mergeMessages([message]);
    _persistHistory();
    return message;
  }

  Future<ChatMessage> sendDirectImageRemote({
    required String authToken,
    required String from,
    required String to,
    required String dataUrl,
  }) async {
    await _historyReady;
    final sendingAccount = _localAccount;
    if (!friends.contains(to)) {
      throw StateError(
        'Both users must follow each other before sending photos.',
      );
    }
    if (blocked.contains(to)) throw StateError('User is blocked');
    if (!dataUrl.startsWith('data:image/')) {
      throw StateError('Invalid image');
    }

    final request = await openBackendRequest(_httpClient, 'POST', 
      apiBase.replace(path: '/message-media'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $authToken',
    );
    request.write(
      jsonEncode(<String, Object>{
        'to_user_id': to,
        'data_url': dataUrl,
      }),
    );
    final response = await closeBackendRequest(request);
    final data = await _readJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error']?.toString() ?? 'Unable to send photo',
      );
    }

    if (sendingAccount != _localAccount) throw StateError('Account changed');
    final raw = data['message'];
    if (raw is! Map) throw StateError('Server returned invalid photo message');
    final createdAtMs = _asInt(raw['created_at']);
    final seenAtMs = _asInt(raw['seen_at']);
    final message = ChatMessage(
      id: raw['id']?.toString(),
      from: raw['from']?.toString() ?? from,
      to: raw['to']?.toString() ?? to,
      text: raw['text']?.toString() ?? 'Photo',
      kind: raw['message_kind']?.toString() ?? 'image',
      mediaUrl: raw['media_url']?.toString(),
      createdAt: createdAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now(),
      seenAt: seenAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(seenAtMs)
          : null,
    );
    if (!message.isImage) {
      throw StateError('Server returned invalid photo message');
    }
    _mergeMessages([message]);
    final localAccount = _localAccount, store = localHistory;
    if (localAccount != null && store != null && message.id != null) {
      try { await store.savePhoto(localAccount, message.id!, base64Decode(dataUrl.split(',').last)); }
      catch (error) { debugPrint('Sent photo could not be saved locally: $error'); }
    }
    _persistHistory();
    return message;
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    final body = await readBackendResponse(response);
    final trimmed = body.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      return <String, dynamic>{};
    } on FormatException {
      final lower = trimmed.toLowerCase();
      if (lower.contains('error code: 1101')) {
        throw StateError(
          'Tinni Star server is temporarily unavailable. Please retry.',
        );
      }
      throw StateError(
        'Tinni Star server returned an invalid response. Please retry.',
      );
    }
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void dispose() {
    _messageEventsWanted = false;
    _messageAuthToken = null;
    _messageConnectTimeout?.cancel();
    final pending = _pendingMessageConnection;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Message service disposed'));
    }
    unawaited(_messageSocketSubscription?.cancel());
    unawaited(_messageSocket?.close());
    _messageSocket = null;
    unreadMessages.dispose();
    messageEvents.dispose();
    roomEvents.dispose();
    accountEvents.dispose();
    _accountRead?.cancel();
    _messageReconnectTimer?.cancel();
    _httpClient.close(force: true);
  }
}
