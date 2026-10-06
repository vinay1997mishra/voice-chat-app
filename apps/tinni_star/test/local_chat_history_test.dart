import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/social/local_chat_store.dart';
import 'package:tinni_star/social/social.dart';

void main() {
  late Directory directory;
  late LocalChatStore files;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tinni-private-chat-');
    files = LocalChatStore(directoryProvider: () async => directory);
  });
  tearDown(() async { await directory.delete(recursive: true); });

  Map<String, dynamic> message(String id, {String kind = 'text', String? url}) => {
    'id': id, 'from': 'peer', 'from_name': 'Friend',
    'to': 'user-1', 'text': 'Saved message $id', 'message_kind': kind,
    'media_url': url, 'created_at': DateTime.now().millisecondsSinceEpoch,
  };

  test('received chat and inbox metadata survive a process restart', () async {
    final first = SocialService(localHistory: files);
    await first.bindLocalAccount('one@example.com', 'user-1');
    first.applyMessageEvent(message('old'));
    await first.flushLocalHistory();
    first.dispose();

    final next = SocialService(localHistory: files);
    addTearDown(next.dispose);
    await next.bindLocalAccount('one@example.com', 'user-1');
    expect(next.directMessages.single.text, 'Saved message old');
    expect(next.messageThreads.single.displayName, 'Friend');
  });

  test('server expiry and empty inbox never replace the phone history', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'messages': [], 'threads': []}));
      request.response.close();
    });
    final base = Uri.parse('http://127.0.0.1:${server.port}');
    final first = SocialService(apiBase: base, localHistory: files);
    await first.bindLocalAccount('one@example.com', 'user-1');
    first.applyMessageEvent(message('old'));
    await first.flushLocalHistory();
    first.dispose();

    final next = SocialService(apiBase: base, localHistory: files);
    addTearDown(next.dispose);
    await next.bindLocalAccount('one@example.com', 'user-1');
    final history = await next.loadConversation(
      authToken: 'session', myUserId: 'user-1', peerUserId: 'peer');
    expect(history.single.id, 'old');
    expect((await next.syncInbox('session')).single.lastMessage?.id, 'old');
    await next.flushLocalHistory();
  });

  test('photo bytes survive restart and server deletion without another request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requests = 0;
    var expired = false;
    server.listen((request) {
      requests++;
      expect(request.headers.value(HttpHeaders.authorizationHeader), 'Bearer session');
      if (expired) { request.response.statusCode = 404; }
      else { request.response.add([1, 2, 3, 4]); }
      request.response.close();
    });
    final base = Uri.parse('http://127.0.0.1:${server.port}');
    final row = message('photo', kind: 'image', url: '${base.origin}/message-media/photo');
    final first = SocialService(apiBase: base, localHistory: files);
    await first.bindLocalAccount('one@example.com', 'user-1');
    first.applyMessageEvent(row);
    final photo = first.directMessages.single;
    final bytes = await first.loadMessagePhoto(authToken: 'session', message: photo);
    expect(bytes, [1, 2, 3, 4]);
    await first.flushLocalHistory();
    first.dispose();
    expired = true;

    final next = SocialService(apiBase: base, localHistory: files);
    addTearDown(next.dispose);
    await next.bindLocalAccount('one@example.com', 'user-1');
    expect(await next.loadMessagePhoto(authToken: 'session', message: next.directMessages.single), bytes);
    expect(requests, 1);
  });

  test('switching accounts isolates history, photos and relationship state', () async {
    final social = SocialService(localHistory: files);
    addTearDown(social.dispose);
    await social.bindLocalAccount('one@example.com', 'user-1');
    social.applyMessageEvent(message('same-id'));
    social.friends.add('peer');
    await social.flushLocalHistory();
    final scope = '${social.apiBase.origin}|one@example.com';
    await files.savePhoto(scope, 'same-id', Uint8List.fromList([1, 2]));

    await social.bindLocalAccount('two@example.com', 'user-2');
    expect(social.directMessages, isEmpty);
    expect(social.messageThreads, isEmpty);
    expect(social.friends, isEmpty);
    expect(await files.readPhoto('${social.apiBase.origin}|two@example.com', 'same-id'), isNull);

    await social.bindLocalAccount('one@example.com', 'user-1');
    expect(social.directMessages.single.id, 'same-id');
    expect(await files.readPhoto(scope, 'same-id'), [1, 2]);
    await social.flushLocalHistory();
  });

  test('public ID changes preserve the same account history', () async {
    final social = SocialService(localHistory: files);
    addTearDown(social.dispose);
    await social.bindLocalAccount('one@example.com', 'user-1');
    social.applyMessageEvent(message('old-id'));
    await social.flushLocalHistory();
    await social.bindLocalAccount('one@example.com', 'new-user-id');
    expect(social.directMessages.single.to, 'new-user-id');
    await social.flushLocalHistory();
  });

  test('message delta merges and duplicate live events do not duplicate saved messages', () async {
    final social = SocialService(localHistory: files);
    addTearDown(social.dispose);
    await social.bindLocalAccount('one@example.com', 'user-1');
    social.applyMessageEvent(message('first'));
    social.applyMessageEvent(message('first'));
    social.applyMessageEvent(message('second'));
    await social.flushLocalHistory();
    expect(social.directMessages.map((row) => row.id), ['first', 'second']);
    expect((await files.load('${social.apiBase.origin}|one@example.com'))['messages'], hasLength(2));
  });

  test('untrusted photo URL never receives the session token', () async {
    final social = SocialService(localHistory: files);
    addTearDown(social.dispose);
    await social.bindLocalAccount('one@example.com', 'user-1');
    expect(await social.loadMessagePhoto(authToken: 'secret',
      message: const ChatMessage(id: 'bad', from: 'peer', to: 'user-1',
        text: 'Photo', kind: 'image', mediaUrl: 'https://other.example/message-media/bad')), isNull);
  });
}
