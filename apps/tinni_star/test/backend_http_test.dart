import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/infra/backend_http.dart';
import 'package:tinni_star/infra/app_backend_service.dart';
import 'package:tinni_star/room/room_presence_service.dart';

void main() {
  test('stalled response headers have a deadline', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = HttpClient();
    final requests = <HttpRequest>[];
    server.listen(requests.add);
    try {
      final request = await openBackendRequest(client, 'GET',
        Uri.parse('http://127.0.0.1:${server.port}/'));
      await expectLater(closeBackendRequest(request,
        timeout: const Duration(milliseconds: 60)), throwsA(isA<TimeoutException>()));
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });

  test('stalled response bodies have a deadline', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = HttpClient();
    server.listen((request) async {
      request.response.bufferOutput = false;
      request.response.write('{');
      await request.response.flush();
    });
    try {
      final request = await openBackendRequest(client, 'GET',
        Uri.parse('http://127.0.0.1:${server.port}/'));
      final response = await closeBackendRequest(request);
      await expectLater(readBackendResponse(response,
        timeout: const Duration(milliseconds: 60)), throwsA(isA<TimeoutException>()));
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });

  test('gift submissions are never automatically replayed on a server error', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var count = 0;
    server.listen((request) async {
      count++;
      await request.drain<void>();
      request.response.statusCode = 503;
      request.response.write('{"error":"Server is temporarily unavailable"}');
      await request.response.close();
    });
    final presence = RoomPresenceService(apiBase: Uri.parse('http://127.0.0.1:${server.port}'));
    try {
      await expectLater(presence.sendGift(roomId: 'room', authToken: 'token',
        giftId: 'rose', giftName: 'Rose', quantity: 1, unitPrice: 100,
        receiverIds: ['receiver']), throwsA(isA<StateError>()));
      expect(count, 1);
    } finally {
      presence.dispose();
      await server.close(force: true);
    }
  });

  test('confirmed unauthorized responses report the expired token', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = HttpClient();
    server.listen((request) async {
      request.response.statusCode = 401;
      request.response.write('{"error":"Unauthorized"}');
      await request.response.close();
    });
    final backend = AppBackendService(apiBase: Uri.parse('http://127.0.0.1:${server.port}'), httpClient: client);
    String? expired;
    backend.onSessionExpired = (token) => expired = token;
    try {
      await expectLater(backend.currentUser('old-token'), throwsA(isA<StateError>()));
      expect(expired, 'old-token');
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });
}
