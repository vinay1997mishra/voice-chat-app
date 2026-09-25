import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'fruit_jackpot_game.dart';

class FruitJackpotRemoteService extends ChangeNotifier {
  FruitJackpotRemoteService({
    Uri? apiBase,
    HttpClient? httpClient,
  })  : apiBase = apiBase ??
            Uri.parse('https://tinnistar-api.tinnistarchat.workers.dev'),
        _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  bool connected = false;
  bool loading = false;
  String? lastError;

  int currentRoundId = 0;
  int jackpot = 0;
  int totalBet = 0;
  int activePlayers = 0;
  int walletBalance = 0;
  int todayWinnings = 0;
  int betLockMs = 3000;

  int _roundEndMs = 0;
  int _serverOffsetMs = 0;

  final Map<FruitKind, int> myBets = <FruitKind, int>{
    for (final fruit in FruitKind.values) fruit: 0,
  };

  final List<FruitRoundResult> history = <FruitRoundResult>[];

  Duration remaining() {
    if (!connected || _roundEndMs <= 0) return Duration.zero;
    final serverNow = DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;
    final value = _roundEndMs - serverNow;
    return Duration(milliseconds: value <= 0 ? 0 : value);
  }

  bool get bettingOpen => connected && remaining().inMilliseconds > betLockMs;

  int userBetForFruit(FruitKind fruit) => myBets[fruit] ?? 0;

  int get userTotalBet =>
      myBets.values.fold<int>(0, (sum, amount) => sum + amount);

  Future<void> sync(String authToken) async {
    if (loading) return;
    loading = true;
    try {
      final startedAt = DateTime.now().millisecondsSinceEpoch;
      final uri = apiBase.replace(path: '/fruit-game/state');
      final request = await _httpClient.getUrl(uri);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $authToken',
      );
      final response = await request.close();
      final data = await _readJson(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          data['error']?.toString() ?? 'Server HTTP ${response.statusCode}',
        );
      }

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
      notifyListeners();
    }
  }

  Future<String?> placeBet({
    required String authToken,
    required FruitKind fruit,
    required int amount,
  }) async {
    if (!connected) return 'Server is reconnecting.';
    if (!bettingOpen) return 'Betting locked for this round.';

    try {
      final uri = apiBase.replace(path: '/fruit-game/bet');
      final request = await _httpClient.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $authToken',
      );
      request.write(
        jsonEncode(<String, Object>{
          'fruit_key': fruit.name,
          'amount': amount,
        }),
      );

      final startedAt = DateTime.now().millisecondsSinceEpoch;
      final response = await request.close();
      final data = await _readJson(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return data['error']?.toString() ?? 'Bet failed.';
      }

      final finishedAt = DateTime.now().millisecondsSinceEpoch;
      final midpoint = startedAt + ((finishedAt - startedAt) ~/ 2);
      _applyState(data, clientMidpointMs: midpoint);
      connected = true;
      lastError = null;
      notifyListeners();
      return null;
    } catch (error) {
      connected = false;
      lastError = error.toString();
      notifyListeners();
      return 'Server connection failed.';
    }
  }

  void _applyState(
    Map<String, dynamic> data, {
    required int clientMidpointMs,
  }) {
    final serverTime = _asInt(data['server_time']);
    _serverOffsetMs = serverTime - clientMidpointMs;

    final round = _asMap(data['round']);
    currentRoundId = _asInt(round['round_id']);
    _roundEndMs = _asInt(round['round_end']);
    betLockMs = _asInt(round['bet_lock_ms'], fallback: 3000);
    totalBet = _asInt(round['total_bet']);
    activePlayers = _asInt(round['active_players']);

    jackpot = _asInt(data['jackpot']);
    walletBalance = _asInt(data['wallet_balance']);
    todayWinnings = _asInt(data['today_winnings']);

    final rawMyBets = _asMap(data['my_bets']);
    for (final fruit in FruitKind.values) {
      myBets[fruit] = _asInt(rawMyBets[fruit.name]);
    }

    history
      ..clear()
      ..addAll(
        _asList(data['history']).map(_parseHistory).whereType<FruitRoundResult>(),
      );
  }

  FruitRoundResult? _parseHistory(dynamic value) {
    final row = _asMap(value);
    final fruitMap = _asMap(row['fruit']);
    final fruitName = fruitMap['key']?.toString();
    FruitKind? fruit;
    for (final candidate in FruitKind.values) {
      if (candidate.name == fruitName) {
        fruit = candidate;
        break;
      }
    }
    if (fruit == null) return null;

    final modeName = row['mode']?.toString();
    final mode = modeName == 'margin_target_high_volume'
        ? FruitResultMode.marginTargetHighVolume
        : FruitResultMode.randomLowVolume;

    return FruitRoundResult(
      roundId: _asInt(row['round_id']),
      fruit: fruit,
      mode: mode,
      totalBet: _asInt(row['total_bet']),
      totalPayout: _asInt(row['total_payout']),
      companyRetained: _asInt(row['company_retained']),
      activePlayers: _asInt(row['active_players']),
      settledAt: DateTime.fromMillisecondsSinceEpoch(
        _asInt(row['settled_at']),
        isUtc: true,
      ),
      marginTargetMet: row['margin_target_met'] == true,
    );
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    final body = await utf8.decoder.bind(response).join();
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'error': 'Invalid server response'};
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
    _httpClient.close(force: true);
    super.dispose();
  }
}
