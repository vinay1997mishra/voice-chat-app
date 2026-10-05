import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/social/social.dart';

void main() {
  test('ribbon pushes reuse one connection without triggering message refresh events', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final socketReady = Completer<WebSocket>();
    final subscription = server.listen((request) async {
      requests++;
      final socket = await WebSocketTransformer.upgrade(request);
      socketReady.complete(socket);
    });
    final social = SocialService(apiBase: Uri.parse('http://127.0.0.1:' + server.port.toString()));
    var messageUpdates = 0;
    var unreadUpdates = 0;
    var roomUpdates = 0;
    final delivered = Completer<void>();
    social.messageEvents.addListener(() => messageUpdates++);
    social.unreadMessages.addListener(() => unreadUpdates++);
    social.roomEvents.addListener(() {
      roomUpdates++;
      if (roomUpdates == 21) delivered.complete();
    });
    try {
      await social.connectMessageEvents('test-session');
      final socket = await socketReady.future.timeout(const Duration(seconds: 5));
      socket.add(jsonEncode({'type':'ribbons_snapshot','ribbons':[]}));
      for (var i=0;i<20;i++) {
        socket.add(jsonEncode({'type':'country_ribbon','ribbon':{'id':'r'+i.toString()}}));
      }
      await delivered.future.timeout(const Duration(seconds: 5));
      expect(requests,1);
      expect(roomUpdates,21);
      expect(messageUpdates,0);
      expect(unreadUpdates,0);
      expect(social.messageEventsConnected,isTrue);
      await social.connectMessageEvents('test-session');
      expect(requests,1);
      await social.disconnectMessageEvents();
      await socket.close();
    } finally {
      await social.disconnectMessageEvents();
      social.dispose();
      await subscription.cancel();
      await server.close(force:true);
    }
  });
}
