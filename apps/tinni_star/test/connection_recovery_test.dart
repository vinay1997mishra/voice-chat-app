import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/room/room_presence_service.dart';

Future<void> waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Connection state did not settle');
}

void main() {
  test('room switch replaces the socket and ignores old-room data', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final service = RoomPresenceService(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add(jsonEncode(<String, Object?>{
        'members': <Object>[],
        'mic_mode': request.uri.queryParameters['room_id'] == 'one'
            ? 'apply'
            : 'free',
      }));
    });
    addTearDown(() async {
      await service.disconnectLive();
      service.dispose();
      for (final socket in sockets) {
        unawaited(socket.close());
      }
      await server.close(force: true);
    });

    await service.connectLive(roomId: 'one', authToken: 'token');
    await waitFor(() => service.connected);
    await service.connectLive(roomId: 'two', authToken: 'token');
    await waitFor(() => sockets.length == 2 && service.micMode == 'free');
    expect(service.liveConnected, isTrue);
    service.syncLiveState(seatIndex: 3, micEnabled: false);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(service.liveConnected, isTrue);
    expect(service.micMode, 'free');
  });

  test('late handshake cannot replace a connection after its deadline',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final gate = Completer<void>();
    final sockets = <WebSocket>[];
    var requests = 0;
    final service = RoomPresenceService(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
      liveConnectTimeout: const Duration(milliseconds: 80),
    );
    server.listen((request) async {
      requests++;
      final first = requests == 1;
      if (first) await gate.future;
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add(jsonEncode(<String, Object?>{
        'members': <Object>[],
        'mic_mode': first ? 'apply' : 'free',
      }));
    });
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      await service.disconnectLive();
      service.dispose();
      for (final socket in sockets) {
        unawaited(socket.close());
      }
      await server.close(force: true);
    });

    await service.connectLive(roomId: 'room', authToken: 'token');
    expect(service.liveConnected, isFalse);
    expect(service.liveReconnecting, isTrue);
    await service.connectLive(roomId: 'room', authToken: 'token');
    await waitFor(() => service.micMode == 'free');
    gate.complete();
    await waitFor(() => sockets.length == 2);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(service.liveConnected, isTrue);
    expect(service.micMode, 'free');
  });

  test('same snapshot notifies listeners when the backend recovers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    WebSocket? socket;
    final service = RoomPresenceService(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    server.listen((request) async {
      socket = await WebSocketTransformer.upgrade(request);
      socket!.listen((_) {});
    });
    addTearDown(() async {
      await service.disconnectLive();
      service.dispose();
      unawaited(socket?.close());
      await server.close(force: true);
    });

    await service.connectLive(roomId: 'room', authToken: 'token');
    final snapshot = jsonEncode(<String, Object?>{'members': <Object>[]});
    socket!.add(snapshot);
    await waitFor(() => service.connected);
    service.connected = false;
    service.lastError = 'Temporary backend failure';
    var notifications = 0;
    service.addListener(() => notifications++);
    socket!.add(snapshot);
    await waitFor(() => service.connected);
    expect(service.lastError, isNull);
    expect(notifications, greaterThan(0));
  });
}
