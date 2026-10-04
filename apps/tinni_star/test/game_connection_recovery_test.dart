import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/games/fruit_jackpot_game.dart';
import 'package:tinni_star/games/fruit_jackpot_remote.dart';
import 'package:tinni_star/games/fruit_party_game.dart';
import 'package:tinni_star/games/fruit_party_remote.dart';

Map<String, Object> state() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return <String, Object>{
    'server_time': now,
    'round': <String, Object>{
      'round_id': 1,
      'round_end': now + 20000,
      'cycle_end': now + 25000,
      'phase': 'betting',
    },
    'my_bets': <String, Object>{},
    'history': <Object>[],
  };
}

void main() {

  test('Jackpot shares pending state refresh and waits for its result',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    final gate = Completer<void>();
    var requests = 0;
    final service = FruitJackpotRemoteService(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    server.listen((request) async {
      requests++;
      if (!received.isCompleted) received.complete();
      await gate.future;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(state()));
      await request.response.close();
    });
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      service.dispose();
      await server.close(force: true);
    });

    final first = service.sync('token');
    await received.future;
    var secondFinished = false;
    final second = service.sync('token').then<void>((_) {
      secondFinished = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(secondFinished, isFalse);
    gate.complete();
    await Future.wait<void>(<Future<void>>[first, second]);
    expect(requests, 1);
    expect(service.connected, isTrue);
    expect(service.loading, isFalse);
  });

  test('Jackpot refreshes disconnected state before submitting one bet',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var stateRequests = 0;
    var betRequests = 0;
    final service = FruitJackpotRemoteService(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET') {
        stateRequests++;
        if (stateRequests == 1) {
          request.response.statusCode = 503;
          request.response.write('{"error":"Temporary outage"}');
          await request.response.close();
          return;
        }
      } else {
        betRequests++;
        await request.drain<void>();
      }
      request.response.write(jsonEncode(state()));
      await request.response.close();
    });
    addTearDown(() async {
      service.dispose();
      await server.close(force: true);
    });

    await service.sync('token');
    expect(service.connected, isFalse);
    final error = await service.placeBet(
      authToken: 'token',
      roomId: 'room',
      fruit: FruitKind.values.first,
      amount: 10,
    );
    expect(error, isNull);
    expect(service.connected, isTrue);
    expect(stateRequests, 2);
    expect(betRequests, 1);
  });

  test('Jackpot clears loading after an incomplete response body',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final service = FruitJackpotRemoteService(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
      requestTimeout: const Duration(milliseconds: 80),
    );
    server.listen((request) async {
      requests++;
      request.response.headers.contentType = ContentType.json;
      if (requests == 1) {
        request.response.write('{');
        await request.response.flush();
        return;
      }
      request.response.write(jsonEncode(state()));
      await request.response.close();
    });
    addTearDown(() async {
      service.dispose();
      await server.close(force: true);
    });

    await service.sync('token');
    expect(service.connected, isFalse);
    expect(service.loading, isFalse);
    expect(service.lastError, contains('TimeoutException'));
    await service.sync('token');
    expect(service.connected, isTrue);
    expect(service.lastError, isNull);
  });

  test('Party shares pending state refresh and waits for its result',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    final gate = Completer<void>();
    var requests = 0;
    final service = FruitPartyRemoteService(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    server.listen((request) async {
      requests++;
      if (!received.isCompleted) received.complete();
      await gate.future;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(state()));
      await request.response.close();
    });
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      service.dispose();
      await server.close(force: true);
    });

    final first = service.sync('token');
    await received.future;
    var secondFinished = false;
    final second = service.sync('token').then<void>((_) {
      secondFinished = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(secondFinished, isFalse);
    gate.complete();
    await Future.wait<void>(<Future<void>>[first, second]);
    expect(requests, 1);
    expect(service.connected, isTrue);
    expect(service.loading, isFalse);
  });

  test('Party refreshes disconnected state before submitting one bet',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var stateRequests = 0;
    var betRequests = 0;
    final service = FruitPartyRemoteService(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET') {
        stateRequests++;
        if (stateRequests == 1) {
          request.response.statusCode = 503;
          request.response.write('{"error":"Temporary outage"}');
          await request.response.close();
          return;
        }
      } else {
        betRequests++;
        await request.drain<void>();
      }
      request.response.write(jsonEncode(state()));
      await request.response.close();
    });
    addTearDown(() async {
      service.dispose();
      await server.close(force: true);
    });

    await service.sync('token');
    expect(service.connected, isFalse);
    final error = await service.placeBet(
      authToken: 'token',
      roomId: 'room',
      fruit: FruitPartyKind.values.first,
      amount: 10,
    );
    expect(error, isNull);
    expect(service.connected, isTrue);
    expect(stateRequests, 2);
    expect(betRequests, 1);
  });

  test('Party clears loading after an incomplete response body',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final service = FruitPartyRemoteService(
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
      requestTimeout: const Duration(milliseconds: 80),
    );
    server.listen((request) async {
      requests++;
      request.response.headers.contentType = ContentType.json;
      if (requests == 1) {
        request.response.write('{');
        await request.response.flush();
        return;
      }
      request.response.write(jsonEncode(state()));
      await request.response.close();
    });
    addTearDown(() async {
      service.dispose();
      await server.close(force: true);
    });

    await service.sync('token');
    expect(service.connected, isFalse);
    expect(service.loading, isFalse);
    expect(service.lastError, contains('TimeoutException'));
    await service.sync('token');
    expect(service.connected, isTrue);
    expect(service.lastError, isNull);
  });
}
