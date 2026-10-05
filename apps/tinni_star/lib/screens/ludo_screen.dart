import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/tinni_state.dart';
import '../games/ludo_game.dart';
import '../room/room_presence_service.dart';
import '../ui/royal_theme.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key, required this.state, required this.roomId});
  final TinniState state;
  final String roomId;
  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> with WidgetsBindingObserver {
  final game = LudoGame();
  final Map<String, Map<String, dynamic>> _players = {};
  String? _myColor, _errorText;
  bool _ready = false, _busy = false, _foreground = true;
  int _version = 0;
  Timer? _poll;
  Future<void>? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.roomSession.addListener(_presenceChanged);
    unawaited(_refresh());
    _startPoll();
  }

  void _presenceChanged() { if (mounted) setState(() {}); }
  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_foreground && !_busy) unawaited(_refresh());
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) { unawaited(_refresh()); _startPoll(); }
    else { _poll?.cancel(); }
  }

  void _apply(Map<String, dynamic> data) {
    final version = (data['version'] as num?)?.toInt() ?? 0;
    if (version < _version) return;
    _version = version;
    game.applyServerState(data);
    _myColor = data['player_color']?.toString();
    _players.clear();
    for (final row in (data['players'] as List? ?? const []).whereType<Map>()) {
      _players[row['color'].toString()] =
        row.map((key, value) => MapEntry(key.toString(), value));
    }
    _ready = true;
    _errorText = null;
  }

  Future<void> _refresh() {
    final existing = _pending;
    if (existing != null) return existing;
    final account = widget.state.auth.current;
    if (account == null) {
      if (mounted) setState(() => _errorText = 'Sign in to play Ludo.');
      return Future<void>.value();
    }
    final future = _read(account.authToken);
    _pending = future;
    return future.whenComplete(() { if (identical(_pending, future)) _pending = null; });
  }
  Future<void> _read(String token) async {
    try {
      final data = await widget.state.backend.ludoState(token, roomId: widget.roomId);
      if (mounted) setState(() => _apply(data));
    } catch (error) {
      if (mounted) setState(() => _errorText = widget.state.backend.userSafeError(error));
    }
  }

  Future<void> _act(Future<Map<String, dynamic>> Function(String) action) async {
    if (_busy || !_ready) return;
    final account = widget.state.auth.current;
    if (account == null) return;
    setState(() => _busy = true);
    try {
      await _pending;
      final future = action(account.authToken);
      final tracked = future.then<void>((data) {
        if (mounted) setState(() => _apply(data));
      });
      _pending = tracked;
      await tracked;
      if (identical(_pending, tracked)) _pending = null;
    } catch (error) {
      _pending = null;
      if (mounted) _snack(widget.state.backend.userSafeError(error));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleVoice() async {
    if (_busy) return;
    final session = widget.state.roomSession;
    if (session.room?.id != widget.roomId) {
      _snack('Enter this room to use its microphone.'); return;
    }
    setState(() => _busy = true);
    try {
      final controller = session.controller;
      if (controller == null) return;
      if (controller.mySeat == null) {
        int? empty;
        for (final seat in controller.seats) {
          if (!seat.locked && !session.liveMembers.any((m) => m.seatIndex == seat.index)) {
            empty = seat.index; break;
          }
        }
        if (empty == null) throw StateError('All room voice seats are occupied.');
        try { await session.takeMySeat(empty); }
        catch (error) {
          if (error.toString().toLowerCase().contains('apply for mic')) {
            await session.requestMySeat(empty);
            _snack('Mic request sent. Waiting for room owner/admin approval.');
            return;
          }
          rethrow;
        }
      }
      await session.toggleMyMic();
    } catch (error) { _snack(widget.state.backend.userSafeError(error)); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  RoomPresenceMember? _member(String userId) {
    for (final member in widget.state.roomSession.liveMembers) {
      if (member.userId == userId) return member;
    }
    return null;
  }
  ImageProvider<Object>? _avatar(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      if (data.startsWith('data:image/') && data.contains(';base64,')) {
        return MemoryImage(base64Decode(data.substring(data.indexOf(',') + 1)));
      }
      if (Uri.tryParse(data)?.scheme == 'https' || Uri.tryParse(data)?.scheme == 'http') {
        return NetworkImage(data);
      }
    } catch (_) {}
    return null;
  }
  Color _color(LudoPlayer player) => switch (player) {
    LudoPlayer.red => const Color(0xFFE5484D),
    LudoPlayer.green => const Color(0xFF31B46C),
    LudoPlayer.yellow => const Color(0xFFF2C94C),
    LudoPlayer.blue => const Color(0xFF3C82F6),
  };
  String _name(LudoPlayer player) =>
      _players[player.name]?['display_name']?.toString() ?? 'Waiting';

  Widget _player(LudoPlayer player) {
    final row = _players[player.name];
    final id = row?['user_id']?.toString() ?? '';
    final member = _member(id);
    final mine = id.isNotEmpty && id == widget.state.auth.current?.userId;
    final voice = mine
        ? widget.state.roomSession.connected && widget.state.realtime.rtc.publishingMic
        : member?.micEnabled == true;
    final turn = _ready && game.currentPlayer == player && row != null;
    return Expanded(child: Container(
      key: Key('ludo-player-' + player.name),
      height: 52, margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color(player).withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color(player), width: turn ? 2 : 1)),
      child: Row(children: [
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(radius: 13, backgroundColor: _color(player),
            foregroundImage: _avatar(member?.avatarDataUrl ?? row?['avatar_data_url']?.toString()),
            child: Icon(row == null ? Icons.event_seat : Icons.person, size: 17, color: Colors.white)),
          Text(_name(player), key: Key('ludo-name-' + player.name),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        ])),
        Text(player.name.substring(0,1).toUpperCase(),
          style: TextStyle(color: _color(player), fontSize: 11, fontWeight: FontWeight.w900)),
        IconButton(key: Key('ludo-mic-' + player.name),
          tooltip: mine ? 'Toggle your room microphone' : (voice ? 'Microphone on' : 'Microphone off'),
          padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 30, height: 32),
          onPressed: mine && !_busy ? _toggleVoice : null,
          icon: Icon(voice ? Icons.mic : Icons.mic_off,
            color: voice ? const Color(0xFF86EFC6) : Colors.white54, size: 18)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mine = _myColor == game.currentPlayer.name;
    final movable = game.movableTokenIndexes();
    final owner = widget.state.roomSession.room?.ownerId == widget.state.auth.current?.userId;
    return Scaffold(backgroundColor: const Color(0xFF111426),
      appBar: AppBar(toolbarHeight: 32, title: const Text('Ludo', style: TextStyle(fontSize: 16)),
        actions: [
          if (owner) IconButton(tooltip: 'Restart Ludo', icon: const Icon(Icons.restart_alt, size: 20),
            onPressed: _ready && !_busy ? () => _act((token) =>
              widget.state.backend.ludoReset(token, roomId: widget.roomId)) : null),
          IconButton(tooltip: 'Refresh Ludo', icon: const Icon(Icons.refresh, size: 20),
            onPressed: _busy ? null : _refresh),
        ]),
      body: SafeArea(top: false, child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(children: [
            Expanded(child: Text(_errorText ?? (!_ready ? 'Connecting…' :
              game.winner != null ? _name(game.winner!) + ' won!' : _name(game.currentPlayer) + ' • ' + game.status),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10))),
            const SizedBox(width: 6),
            SizedBox(height: 30, child: FilledButton(
              key: const Key('ludo-roll-dice'),
              style: FilledButton.styleFrom(backgroundColor: _color(game.currentPlayer),
                foregroundColor: game.currentPlayer == LudoPlayer.yellow ? Colors.black : Colors.white),
              onPressed: _ready && !_busy && mine && game.rolled == null && game.winner == null
                ? () => _act((token) => widget.state.backend.ludoRoll(token, roomId: widget.roomId)) : null,
              child: Text(_busy ? '…' : game.rolled == null ? 'ROLL' : 'Dice ' + game.rolled.toString(),
                style: const TextStyle(fontSize: 11)))),
          ])),
        Row(children: [_player(LudoPlayer.red), _player(LudoPlayer.green)]),
        const SizedBox(height: 4),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final side = math.min(constraints.maxWidth - 16, constraints.maxHeight).clamp(0.0, double.infinity);
          return Center(child: SizedBox(width: side, height: side,
            child: CustomPaint(painter: _LudoBoardPainter(game: game, playerColor: _color),
              child: Stack(children: [
                for (final player in LudoPlayer.values)
                  for (final token in game.tokens[player]!)
                    _TokenButton(token: token, game: game, boardSize: side,
                      color: _color(player), enabled: _ready && !_busy && mine &&
                        player == game.currentPlayer && movable.contains(token.index),
                      onTap: () => _act((auth) => widget.state.backend.ludoMove(
                        auth, roomId: widget.roomId, tokenIndex: token.index))),
              ])),
          ));
        })),
        const SizedBox(height: 4),
        Row(children: [_player(LudoPlayer.blue), _player(LudoPlayer.yellow)]),
        const SizedBox(height: 4),
      ])),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.state.roomSession.removeListener(_presenceChanged);
    final account = widget.state.auth.current;
    final pending = _pending;
    if (account != null) {
      unawaited(() async {
        try {
          await pending;
          await widget.state.backend.ludoLeave(account.authToken, roomId: widget.roomId);
        } catch (_) {}
      }());
    }
    super.dispose();
  }
}

class _TokenButton extends StatelessWidget {
  const _TokenButton({
    required this.token,
    required this.game,
    required this.boardSize,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final LudoToken token;
  final LudoGame game;
  final double boardSize;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final position = _LudoGeometry.positionFor(token, game, boardSize);
    return Positioned(
      key: Key('ludo-token-' + token.player.name + '-' + token.index.toString()),
      left: position.dx - boardSize / 30,
      top: position.dy - boardSize / 30,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: boardSize / 15,
          height: boardSize / 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: enabled ? Colors.white : Colors.black54,
              width: enabled ? 3 : 1.5,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          alignment: Alignment.center,
          child: Text(
            '${token.index + 1}',
            style: const TextStyle(
              color: token.player == LudoPlayer.yellow ? Colors.black : Colors.white,
              fontSize: math.max(6.0, boardSize / 45),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _LudoGeometry {
  static const double boardCells = 15;

  static List<Offset> track(double size) {
    final cell = size / boardCells;
    const cells = <Offset>[
      Offset(1,6),Offset(2,6),Offset(3,6),Offset(4,6),Offset(5,6),
      Offset(6,5),Offset(6,4),Offset(6,3),Offset(6,2),Offset(6,1),Offset(6,0),Offset(7,0),Offset(8,0),
      Offset(8,1),Offset(8,2),Offset(8,3),Offset(8,4),Offset(8,5),
      Offset(9,6),Offset(10,6),Offset(11,6),Offset(12,6),Offset(13,6),Offset(14,6),Offset(14,7),Offset(14,8),
      Offset(13,8),Offset(12,8),Offset(11,8),Offset(10,8),Offset(9,8),
      Offset(8,9),Offset(8,10),Offset(8,11),Offset(8,12),Offset(8,13),Offset(8,14),Offset(7,14),Offset(6,14),
      Offset(6,13),Offset(6,12),Offset(6,11),Offset(6,10),Offset(6,9),
      Offset(5,8),Offset(4,8),Offset(3,8),Offset(2,8),Offset(1,8),Offset(0,8),Offset(0,7),Offset(0,6),
    ];
    return cells.map((p) => Offset((p.dx+.5)*cell,(p.dy+.5)*cell)).toList();
  }

  static Offset positionFor(
    LudoToken token,
    LudoGame game,
    double size,
  ) {
    final cell = size / boardCells;

    if (token.isHome) {
      const homes = <LudoPlayer, List<Offset>>{
        LudoPlayer.red: [
          Offset(2.0, 2.0),
          Offset(4.0, 2.0),
          Offset(2.0, 4.0),
          Offset(4.0, 4.0),
        ],
        LudoPlayer.green: [
          Offset(10.5, 2.0),
          Offset(12.5, 2.0),
          Offset(10.5, 4.0),
          Offset(12.5, 4.0),
        ],
        LudoPlayer.yellow: [
          Offset(10.5, 10.5),
          Offset(12.5, 10.5),
          Offset(10.5, 12.5),
          Offset(12.5, 12.5),
        ],
        LudoPlayer.blue: [
          Offset(2.0, 10.5),
          Offset(4.0, 10.5),
          Offset(2.0, 12.5),
          Offset(4.0, 12.5),
        ],
      };
      final p = homes[token.player]![token.index];
      return Offset(p.dx * cell, p.dy * cell);
    }

    if (token.progress < 52) {
      return track(size)[game.sharedTrackIndex(token.player, token.progress)];
    }

    final step = (token.progress - 51).clamp(1, 6);
    final point = switch(token.player) {
      LudoPlayer.red => Offset(step.toDouble(),7),
      LudoPlayer.green => Offset(7,step.toDouble()),
      LudoPlayer.yellow => Offset(14-step.toDouble(),7),
      LudoPlayer.blue => Offset(7,14-step.toDouble()),
    };
    return Offset((point.dx+.5)*cell,(point.dy+.5)*cell);
  }

}

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter({
    required this.game,
    required this.playerColor,
  });

  final LudoGame game;
  final Color Function(LudoPlayer) playerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final cell = side / _LudoGeometry.boardCells;

    final background = Paint()..color = const Color(0xFFF4EAD2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, side, side),
        const Radius.circular(18),
      ),
      background,
    );

    final homeRects = <LudoPlayer, Rect>{
      LudoPlayer.red: Rect.fromLTWH(0, 0, 6 * cell, 6 * cell),
      LudoPlayer.green: Rect.fromLTWH(9 * cell, 0, 6 * cell, 6 * cell),
      LudoPlayer.yellow:
          Rect.fromLTWH(9 * cell, 9 * cell, 6 * cell, 6 * cell),
      LudoPlayer.blue: Rect.fromLTWH(0, 9 * cell, 6 * cell, 6 * cell),
    };

    for (final entry in homeRects.entries) {
      canvas.drawRect(
        entry.value,
        Paint()..color = playerColor(entry.key).withValues(alpha: .78),
      );
    }

    final pathPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFF8D846E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final point in _LudoGeometry.track(side)) {
      final rect = Rect.fromCenter(
        center: point,
        width: cell,
        height: cell,
      );
      canvas.drawRect(rect, pathPaint);
      canvas.drawRect(rect, border);
    }

    for (final player in LudoPlayer.values) {
      final start = _LudoGeometry.track(side)[LudoGame.startOffsets[player]!];
      canvas.drawRect(Rect.fromCenter(center:start,width:cell,height:cell),
        Paint()..color=playerColor(player));
      for (var step=1;step<=6;step++) {
        final point=_LudoGeometry.positionFor(LudoToken(player:player,index:0,progress:51+step),game,side);
        canvas.drawRect(Rect.fromCenter(center:point,width:cell,height:cell),Paint()..color=playerColor(player));
        canvas.drawRect(Rect.fromCenter(center:point,width:cell,height:cell),border);
      }
    }
    final middle = Offset(side/2,side/2);
    final corners = [Offset(6*cell,6*cell),Offset(9*cell,6*cell),
      Offset(9*cell,9*cell),Offset(6*cell,9*cell)];
    for (var index=0;index<4;index++) {
      final triangle=Path()..moveTo(middle.dx,middle.dy)
        ..lineTo(corners[index].dx,corners[index].dy)
        ..lineTo(corners[(index+1)%4].dx,corners[(index+1)%4].dy)..close();
      canvas.drawPath(triangle,Paint()..color=playerColor(
        [LudoPlayer.green,LudoPlayer.yellow,LudoPlayer.blue,LudoPlayer.red][index]));
    }
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) => true;
}
