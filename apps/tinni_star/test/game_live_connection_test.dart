import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/games/game_live_connection.dart';

class _RealHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context);
}

void main() {
  test('game socket receives snapshots, coalesces changes and stops after disconnect', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = Completer<WebSocket>();
      var requests = 0, stateReads = 0;
      final listener = server.listen((request) async {
        requests++;
        expect(request.uri.path, '/ludo/live');
        expect(request.uri.queryParameters['room_id'], 'room-a');
        expect(request.headers.value(HttpHeaders.authorizationHeader), 'Bearer test-token');
        final socket = await WebSocketTransformer.upgrade(request);
        accepted.complete(socket);
        socket.listen((raw) {
          final data = jsonDecode(raw as String) as Map;
          expect(data['type'], 'state');
          stateReads++;
          socket.add(jsonEncode({'type': 'game_state', 'state': {'version': 2}}));
        });
        socket.add(jsonEncode({'type': 'game_state', 'state': {'version': 1}}));
      });
      final baseline = Completer<void>(), update = Completer<void>();
      final live = GameLiveConnection(
        apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
        path: '/ludo/live', roomId: 'room-a', onStatus: () {},
        onState: (state) {
          if (state['version'] == 1 && !baseline.isCompleted) baseline.complete();
          if (state['version'] == 2 && !update.isCompleted) update.complete();
        },
      );
      try {
        await live.connect('test-token');
        await baseline.future.timeout(const Duration(seconds: 3));
        expect(live.connected, true);
        final socket = await accepted.future;
        for (var i = 0; i < 20; i++) {
          socket.add(jsonEncode({'type': 'game_changed'}));
        }
        await update.future.timeout(const Duration(seconds: 3));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(stateReads, 1);
        expect(requests, 1);
        live.disconnect();
        expect(live.connected, false);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(requests, 1);
      } finally {
        live.disconnect();
        await listener.cancel();
        await server.close(force: true);
      }
    }, _RealHttp());
  });
}
