import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../infra/backend_http.dart';
import 'game_live_connection.dart';

import 'package:flutter/foundation.dart';

import 'fruit_party_game.dart';

class FruitPartyRemoteService extends ChangeNotifier {
  FruitPartyRemoteService({
    Uri? apiBase,
    HttpClient? httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  })  : apiBase = apiBase ??
            Uri.parse('https://tinni-star-api.mishrajii7991.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;
  final Duration requestTimeout;
  Future<void>? _syncFuture;
  bool _disposed = false;
  int _latestServerTime = 0;
  late final _live = GameLiveConnection(apiBase: apiBase, path: '/fruit-party/live',
    onState: (data) {
      if (_disposed) return;
      _applyState(data, clientMidpointMs: DateTime.now().millisecondsSinceEpoch);
      connected = true;
      lastError = null;
    }, onStatus: () { if (!_disposed) notifyListeners(); });
  bool get liveConnected => _live.connected;
  Future<void> connectLive(String token) => _disposed ? Future<void>.value() : _live.connect(token);
  void disconnectLive() => _live.disconnect();

  bool connected = false;
  bool loading = false;
  String? lastError;

  int currentRoundId = 0;
  int totalBet = 0;
  int activePlayers = 0;
  int walletBalance = 0;
  Map<String, dynamic>? lastBetResult;
  int todayWinnings = 0;
  int betLockMs = 0;
  int roundDurationMs = 21000;
  int resultSpinMs = 5000;
  String phase = 'betting';

  int _roundEndMs = 0;
  int _cycleEndMs = 0;
  int _serverOffsetMs = 0;

  final Map<FruitPartyKind, int> myBets = <FruitPartyKind, int>{
    for (final fruit in FruitPartyKind.values) fruit: 0,
  };

  final List<FruitPartyRoundResult> history = <FruitPartyRoundResult>[];

  Duration remaining() {
    if (!connected || _roundEndMs <= 0) return Duration.zero;
    final serverNow = DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;
    final value = _roundEndMs - serverNow;
    return Duration(milliseconds: value <= 0 ? 0 : value);
  }

  Duration resultSpinRemaining() {
    if (!connected || _cycleEndMs <= 0 || phase != 'result_spin') {
      return Duration.zero;
    }
    final serverNow = DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;
    final value = _cycleEndMs - serverNow;
    return Duration(milliseconds: value <= 0 ? 0 : value);
  }

  bool get inResultSpin =>
      connected &&
      phase == 'result_spin' &&
      resultSpinRemaining().inMilliseconds > 0;

  bool get bettingOpen =>
      connected && phase == 'betting' && remaining().inMilliseconds > 0;

  int userBetForFruit(FruitPartyKind fruit) => myBets[fruit] ?? 0;

  int get userTotalBet =>
      myBets.values.fold<int>(0, (sum, amount) => sum + amount);

  Future<void> sync(String authToken) {
    if (_disposed) return Future<void>.value();
    final pending = _syncFuture;
    if (pending != null) return pending;
    final operation = _sync(authToken);
    _syncFuture = operation;
    return operation.whenComplete(() {
      if (identical(_syncFuture, operation)) _syncFuture = null;
    });
  }

  Future<void> _sync(String authToken) async {
    loading = true;
    try {
      final startedAt = DateTime.now().millisecondsSinceEpoch;
      final uri = apiBase.replace(path: '/fruit-party/state');
      final request = await openBackendRequest(_httpClient, 'GET', uri).timeout(requestTimeout);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $authToken',
      );
      final data = await _requestJson(request);

      final finishedAt = DateTime.now().millisecondsSinceEpoch;
      final midpoint = startedAt + ((finishedAt - startedAt) ~/ 2);
      _applyState(data, clientMidpointMs: midpoint);
      connected = true;
      lastError = null;
    } catch (error) {
      connected = false;
      lastError = error.toString();
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<String?> placeBet({
    required String authToken,
    required String roomId,
    required FruitPartyKind fruit,
    required int amount,
  }) async {
    if (!connected) {
      await sync(authToken);
      if (!connected) {
        return lastError?.replaceFirst('Bad state: ', '') ??
            'Server connection failed. Please retry.';
      }
    }
    if (!bettingOpen) return 'Betting locked for this round.';

    try {
      final uri = apiBase.replace(path: '/fruit-party/bet');
      final request = await openBackendRequest(_httpClient, 'POST', uri).timeout(requestTimeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $authToken',
      );
      request.write(
        jsonEncode(<String, Object>{
          'request_id': List.generate(16, (_) => math.Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join(),
          'fruit_key': fruit.name,
          'amount': amount,
          'room_id': roomId,
        }),
      );

      final startedAt = DateTime.now().millisecondsSinceEpoch;
      final data = await _requestJson(request);

      final finishedAt = DateTime.now().millisecondsSinceEpoch;
      final midpoint = startedAt + ((finishedAt - startedAt) ~/ 2);
      _applyState(data, clientMidpointMs: midpoint);
      connected = true;
      lastError = null;
      if (!_disposed) notifyListeners();
      return null;
    } catch (error) {
      connected = false;
      lastError = error.toString();
      if (!_disposed) notifyListeners();
      return lastError!.replaceFirst('Bad state: ', '');
    }
  }

  Future<Map<String, dynamic>> _requestJson(HttpClientRequest request) async {
    try {
      final response = await closeBackendRequest(request).timeout(requestTimeout);
      final data = await _readJson(response).timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          data['error']?.toString() ?? 'Server HTTP ${response.statusCode}',
        );
      }
      return data;
    } catch (error) {
      request.abort(error);
      rethrow;
    }
  }

  void _applyState(
    Map<String, dynamic> data, {
    required int clientMidpointMs,
  }) {
    final serverTime = _asInt(data['server_time']);
    if (serverTime > 0 && serverTime < _latestServerTime) return;
    _latestServerTime = serverTime;
    _serverOffsetMs = serverTime - clientMidpointMs;

    final round = _asMap(data['round']);
    currentRoundId = _asInt(round['round_id']);
    _roundEndMs = _asInt(round['round_end']);
    _cycleEndMs = _asInt(round['cycle_end'], fallback: _roundEndMs);
    betLockMs = _asInt(round['bet_lock_ms']);
    roundDurationMs = _asInt(
      round['round_duration_ms'],
      fallback: 21000,
    );
    resultSpinMs = _asInt(
      round['result_spin_ms'],
      fallback: 5000,
    );
    phase = round['phase']?.toString() ?? 'betting';
    totalBet = _asInt(round['total_bet']);
    activePlayers = _asInt(round['active_players']);

    walletBalance = _asInt(data['wallet_balance']);
    lastBetResult = data['last_bet_result'] is Map ? _asMap(data['last_bet_result']) : null;
    todayWinnings = _asInt(data['today_winnings']);

    final rawMyBets = _asMap(data['my_bets']);
    for (final fruit in FruitPartyKind.values) {
      myBets[fruit] = _asInt(rawMyBets[fruit.name]);
    }

    history
      ..clear()
      ..addAll(
        _asList(data['history'])
            .map(_parseHistory)
            .whereType<FruitPartyRoundResult>(),
      );
  }

  FruitPartyRoundResult? _parseHistory(dynamic value) {
    final row = _asMap(value);
    final fruitMap = _asMap(row['fruit']);
    final fruitName = fruitMap['key']?.toString();
    FruitPartyKind? fruit;

    for (final candidate in FruitPartyKind.values) {
      if (candidate.name == fruitName) {
        fruit = candidate;
        break;
      }
    }
    if (fruit == null) return null;


    return FruitPartyRoundResult(
      roundId: _asInt(row['round_id']),
      fruit: fruit,
      lucky11: row['special_kind'] == 'lucky11',
      bonusFruits: [for (final item in _asList(row['bonus_fruits']))
        for (final candidate in FruitPartyKind.values)
          if (candidate.name == _asMap(item)['key']) candidate],
      totalBet: _asInt(row['total_bet']),
      totalPayout: _asInt(row['total_payout']),
      activePlayers: _asInt(row['active_players']),
      settledAt: DateTime.fromMillisecondsSinceEpoch(
        _asInt(row['settled_at']),
        isUtc: true,
      ),
    );
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

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : const <dynamic>[];
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  void dispose() {
    _disposed = true;
    _live.disconnect();
    _httpClient.close(force: true);
    super.dispose();
  }
}
