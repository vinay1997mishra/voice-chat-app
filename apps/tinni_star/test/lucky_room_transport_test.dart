import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/room/room_presence_service.dart';

void main() {
  test('two room clients retain complete Lucky data, common timing and burst events', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final ready = Completer<void>();
    final subscription = server.listen((request) async {
      sockets.add(await WebSocketTransformer.upgrade(request));
      if (sockets.length == 2) ready.complete();
    });
    final base = Uri.parse('http://127.0.0.1:${server.port}');
    final clients = [RoomPresenceService(apiBase: base), RoomPresenceService(apiBase: base)];
    final complete = [Completer<void>(), Completer<void>()];
    for (var i = 0; i < clients.length; i++) {
      clients[i].addListener(() {
        if (clients[i].giftVisualEvents.length == 3 && !complete[i].isCompleted) complete[i].complete();
      });
    }
    try {
      for (final client in clients) {
        await client.connectLive(roomId: 'room', authToken: 'test-token');
      }
      await ready.future.timeout(const Duration(seconds: 5));
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final socket in sockets) {
        for (var i = 0; i < 3; i++) {
          socket.add(jsonEncode({'type': 'gift_sent', 'gift': {
            'id': 'send-$i', 'sender_id': 'sender', 'sender_name': 'Sender',
            'gift_id': 'lucky-neon-butterfly', 'gift_name': 'Neon Butterfly',
            'receiver_ids': ['receiver'], 'quantity': 99, 'lucky': true,
            'multiplier': 1000, 'rebate_coins': 510000, 'sent_coins': 49500,
            'unit_price': 500, 'created_at': now, 'server_time': now,
            'visual_started_at': now + 450 + i * 4900, 'visual_duration_ms': 4900,
            'high_win': true, 'banner_win': true, 'ultra_win': true,
            'multiplier_counts': [{'multiplier': 0, 'count': 97},
              {'multiplier': 20, 'count': 1}, {'multiplier': 1000, 'count': 1}],
          }}));
        }
      }
      await Future.wait(complete.map((c) => c.future)).timeout(const Duration(seconds: 5));
      for (var i = 0; i < 3; i++) {
        final a = clients[0].giftVisualEvents[i], b = clients[1].giftVisualEvents[i];
        expect(a.id, b.id);
        expect(a.visualStartedAtMs, b.visualStartedAtMs);
        expect(a.visualDurationMs, b.visualDurationMs);
        expect(a.multiplierCounts, b.multiplierCounts);
        expect(a.sentCoins, 49500);
        expect(a.unitPrice, 500);
        expect(a.rebateCoins, 510000);
      }
      await clients[0].disconnectLive();
      expect(clients[0].giftVisualEvents, isEmpty);
      expect(clients[0].latestGiftVisualEvent, isNull);
    } finally {
      for (final client in clients) {
        await client.disconnectLive(); client.dispose();
      }
      for (final socket in sockets) { await socket.close(); }
      await subscription.cancel(); await server.close(force: true);
    }
  });
}
