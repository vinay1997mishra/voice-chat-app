import 'package:flutter/material.dart';

import '../games/ludo_game.dart';
import '../ui/royal_theme.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  late LudoGame game;

  @override
  void initState() {
    super.initState();
    game = LudoGame();
  }

  Color _playerColor(LudoPlayer player) {
    switch (player) {
      case LudoPlayer.red:
        return const Color(0xFFE5484D);
      case LudoPlayer.green:
        return const Color(0xFF31B46C);
      case LudoPlayer.yellow:
        return const Color(0xFFF2C94C);
      case LudoPlayer.blue:
        return const Color(0xFF3C82F6);
    }
  }

  String _playerName(LudoPlayer player) {
    return player.name[0].toUpperCase() + player.name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final movable = game.movableTokenIndexes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo'),
        actions: [
          IconButton(
            tooltip: 'Restart',
            onPressed: () => setState(game.reset),
            icon: const ShiningIcon(
              icon: Icons.refresh_rounded,
              color: FeaturePalette.ludo,
              size: 18,
              boxSize: 34,
              glow: 0.30,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: RoyalPanel(
                gradient: FeaturePalette.glow(
                  _playerColor(game.currentPlayer),
                ),
                accentColor: _playerColor(game.currentPlayer),
                child: Row(
                  children: [
                    ShiningIcon(
                      icon: Icons.person_rounded,
                      color: _playerColor(game.currentPlayer),
                      size: 21,
                      boxSize: 42,
                      glow: 0.40,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.winner == null
                                ? '${_playerName(game.currentPlayer)} turn'
                                : '${_playerName(game.winner!)} won',
                            style: const TextStyle(
                              color: RoyalPalette.cream,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            game.status,
                            style: const TextStyle(
                              color: RoyalPalette.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      key: const Key('ludo-roll-dice'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _playerColor(game.currentPlayer),
                        foregroundColor: Colors.white,
                        shadowColor: _playerColor(game.currentPlayer),
                        elevation: 5,
                      ),
                      onPressed: game.winner != null || game.rolled != null
                          ? null
                          : () => setState(game.roll),
                      child: Text(
                        game.rolled == null ? 'ROLL' : '🎲 ${game.rolled}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.biggest.shortestSide;
                      return CustomPaint(
                        painter: _LudoBoardPainter(
                          game: game,
                          playerColor: _playerColor,
                        ),
                        child: Stack(
                          children: [
                            for (final player in LudoPlayer.values)
                              for (final token in game.tokens[player]!)
                                _TokenButton(
                                  token: token,
                                  game: game,
                                  boardSize: side,
                                  color: _playerColor(player),
                                  enabled:
                                      player == game.currentPlayer &&
                                      movable.contains(token.index),
                                  onTap: () {
                                    if (game.move(token.index)) {
                                      setState(() {});
                                    }
                                  },
                                ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              child: Row(
                children: [
                  for (final player in LudoPlayer.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: FeaturePalette.glow(
                              _playerColor(player),
                            ),
                            border: Border.all(
                              color: _playerColor(player).withValues(
                                alpha: player == game.currentPlayer ? 1 : 0.55,
                              ),
                              width: player == game.currentPlayer ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _playerColor(player).withValues(
                                  alpha: player == game.currentPlayer
                                      ? 0.38
                                      : 0.14,
                                ),
                                blurRadius:
                                    player == game.currentPlayer ? 14 : 8,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                _playerName(player),
                                style: TextStyle(
                                  color: _playerColor(player),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${game.tokens[player]!.where((t) => t.isFinished).length}/4 home',
                                style: const TextStyle(
                                  color: RoyalPalette.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      left: position.dx - 13,
      top: position.dy - 13,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 26,
          height: 26,
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
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _LudoGeometry {
  static const double boardCells = 14;

  static List<Offset> track(double size) {
    final cell = size / boardCells;
    final cells = <Offset>[];

    for (var x = 0; x < 14; x++) {
      cells.add(Offset((x + .5) * cell, .5 * cell));
    }
    for (var y = 1; y < 14; y++) {
      cells.add(Offset(13.5 * cell, (y + .5) * cell));
    }
    for (var x = 12; x >= 0; x--) {
      cells.add(Offset((x + .5) * cell, 13.5 * cell));
    }
    for (var y = 12; y >= 1; y--) {
      cells.add(Offset(.5 * cell, (y + .5) * cell));
    }
    return cells;
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
          Offset(10.0, 2.0),
          Offset(12.0, 2.0),
          Offset(10.0, 4.0),
          Offset(12.0, 4.0),
        ],
        LudoPlayer.yellow: [
          Offset(10.0, 10.0),
          Offset(12.0, 10.0),
          Offset(10.0, 12.0),
          Offset(12.0, 12.0),
        ],
        LudoPlayer.blue: [
          Offset(2.0, 10.0),
          Offset(4.0, 10.0),
          Offset(2.0, 12.0),
          Offset(4.0, 12.0),
        ],
      };
      final p = homes[token.player]![token.index];
      return Offset(p.dx * cell, p.dy * cell);
    }

    if (token.progress < 52) {
      return track(size)[game.sharedTrackIndex(token.player, token.progress)];
    }

    final step = (token.progress - 51).clamp(1, 6);
    final t = step / 6;
    final start = track(size)[LudoGame.startOffsets[token.player]!];
    final center = Offset(size / 2, size / 2);
    return Offset(
      start.dx + (center.dx - start.dx) * t,
      start.dy + (center.dy - start.dy) * t,
    );
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
      LudoPlayer.green: Rect.fromLTWH(8 * cell, 0, 6 * cell, 6 * cell),
      LudoPlayer.yellow:
          Rect.fromLTWH(8 * cell, 8 * cell, 6 * cell, 6 * cell),
      LudoPlayer.blue: Rect.fromLTWH(0, 8 * cell, 6 * cell, 6 * cell),
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

    final center = Path()
      ..moveTo(side / 2, 5.2 * cell)
      ..lineTo(8.8 * cell, side / 2)
      ..lineTo(side / 2, 8.8 * cell)
      ..lineTo(5.2 * cell, side / 2)
      ..close();
    canvas.drawPath(
      center,
      Paint()..color = FeaturePalette.ludo.withValues(alpha: .9),
    );

    final centerText = TextPainter(
      text: const TextSpan(
        text: 'TINNI\nLUDO',
        style: TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    centerText.paint(
      canvas,
      Offset(
        side / 2 - centerText.width / 2,
        side / 2 - centerText.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) => true;
}
