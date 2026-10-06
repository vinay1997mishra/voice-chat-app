import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../infra/request_budget.dart';

/// One hibernating game socket; no periodic HTTP reads while it is ready.
class GameLiveConnection {
  GameLiveConnection({
    required this.apiBase,
    required this.path,
    required this.onState,
    required this.onStatus,
    this.roomId,
  });
  final Uri apiBase;
  final String path;
  final String? roomId;
  final void Function(Map<String, dynamic>) onState;
  final void Function() onStatus;
  WebSocket? _socket;
  Timer? _retry;
  Timer? _refresh;
  Timer? _response;
  bool _wanted = false, _opening = false, _ready = false;
  int _generation = 0, _failures = 0;
  String? _token;
  bool get connected => _ready && _socket?.readyState == WebSocket.open;

  Future<void> connect(String token) async {
    if (token.trim().isEmpty) return;
    if (_wanted && _token != token) disconnect();
    _wanted = true;
    _token = token;
    await _open();
  }

  Future<void> _open() async {
    if (!_wanted || _opening || _socket?.readyState == WebSocket.open) return;
    _opening = true;
    final generation = ++_generation;
    var accepting = true;
    try {
      final uri = apiBase.replace(
        scheme: apiBase.scheme == 'https' ? 'wss' : 'ws',
        path: path, queryParameters: roomId == null ? null : {'room_id': roomId!},
      );
      final socket = await WebSocket.connect(uri.toString(), headers: {
        HttpHeaders.authorizationHeader: 'Bearer $_token',
      }).then((socket) {
        if (!accepting || !_wanted || generation != _generation) {
          unawaited(socket.close());
        }
        return socket;
      }).timeout(const Duration(seconds: 15));
      if (!_wanted || generation != _generation) { await socket.close(); return; }
      _socket = socket;
      _watchResponse(socket);
      // Protocol pings do not run application handlers or write presence rows.
      socket.pingInterval = const Duration(seconds: 30);
      socket.listen((raw) {
        if (generation != _generation || raw is! String) return;
        try {
          final event = jsonDecode(raw);
          if (event is! Map) return;
          if (event['type'] == 'game_state' && event['state'] is Map) {
            _response?.cancel();
            _response = null;
            _ready = true;
            _failures = 0;
            onState(Map<String, dynamic>.from(event['state'] as Map));
            onStatus();
          } else if (event['type'] == 'game_changed') {
            // Coalesce a burst of bets into one socket state read.
            _refresh ??= Timer(const Duration(milliseconds: 200), () {
              _refresh = null;
              if (connected) {
                socket.add(jsonEncode({'type': 'state'}));
                _watchResponse(socket);
              }
            });
          }
        } catch (_) {}
      }, onDone: () => _lost(socket), onError: (_) => _lost(socket), cancelOnError: true);
    } catch (_) {
      if (_wanted && generation == _generation) _scheduleRetry();
    } finally {
      accepting = false;
      if (generation == _generation) _opening = false;
    }
  }

  void _watchResponse(WebSocket socket) {
    _response ??= Timer(const Duration(seconds: 15), () {
      _response = null;
      _lost(socket);
      unawaited(socket.close());
    });
  }

  void _lost(WebSocket socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    _ready = false;
    _response?.cancel();
    _response = null;
    _refresh?.cancel();
    _refresh = null;
    onStatus();
    if (_wanted) _scheduleRetry();
  }
  void _scheduleRetry() {
    if (!_wanted || _retry != null) return;
    _retry = Timer(RequestBudget.reconnectDelay(_failures++), () {
      _retry = null;
      unawaited(_open());
    });
  }
  void disconnect() {
    _wanted = false;
    _generation++;
    _opening = false;
    _ready = false;
    _response?.cancel();
    _response = null;
    _retry?.cancel();
    _retry = null;
    _refresh?.cancel();
    _refresh = null;
    final socket = _socket;
    _socket = null;
    unawaited(socket?.close());
  }
}
