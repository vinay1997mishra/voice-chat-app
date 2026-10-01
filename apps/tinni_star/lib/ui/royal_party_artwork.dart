import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'royal_theme.dart';

class RoyalPartyBackdrop extends StatelessWidget {
  const RoyalPartyBackdrop({
    super.key,
    required this.accent,
    this.intensity = 1,
  });

  final Color accent;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _RoyalPartyBackdropPainter(
          accent: accent,
          intensity: intensity.clamp(0.0, 1.0),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class RoyalPanelOrnament extends StatelessWidget {
  const RoyalPanelOrnament({
    super.key,
    this.color = RoyalPalette.gold,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _RoyalPanelOrnamentPainter(color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class RoyalRankFrame extends StatelessWidget {
  const RoyalRankFrame({
    super.key,
    required this.rank,
    required this.child,
    this.height = 106,
    this.radius = 18,
  });

  final int rank;
  final Widget child;
  final double height;
  final double radius;

  Color get _metal => switch (rank) {
        1 => RoyalPalette.gold,
        2 => const Color(0xFFBEC4CB),
        _ => const Color(0xFFA56C43),
      };

  @override
  Widget build(BuildContext context) {
    final metal = _metal;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            top: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    metal.withValues(alpha: 0.48),
                    RoyalPalette.panel2,
                    RoyalPalette.black,
                    metal.withValues(alpha: 0.18),
                  ],
                  stops: const [0.0, 0.18, 0.72, 1.0],
                ),
                border: Border.all(
                  color: metal.withValues(alpha: 0.82),
                  width: rank == 1 ? 1.8 : 1.35,
                ),
                boxShadow: [
                  BoxShadow(
                    color: metal.withValues(alpha: rank == 1 ? 0.24 : 0.14),
                    blurRadius: rank == 1 ? 16 : 10,
                    spreadRadius: 0.4,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius - 4),
                  child: child,
                ),
              ),
            ),
          ),
          Positioned(
            top: -7,
            child: _RoyalCrown(rank: rank, color: metal),
          ),
          Positioned(
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: RoyalPalette.nearBlack,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: metal.withValues(alpha: 0.88)),
                boxShadow: [
                  BoxShadow(
                    color: metal.withValues(alpha: 0.16),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                'TOP $rank',
                style: TextStyle(
                  color: metal,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RoyalRankHalo extends StatelessWidget {
  const RoyalRankHalo({
    super.key,
    required this.rank,
    required this.child,
    this.size = 52,
  });

  final int rank;
  final Widget child;
  final double size;

  Color get _metal => switch (rank) {
        1 => RoyalPalette.gold,
        2 => const Color(0xFFBEC4CB),
        _ => const Color(0xFFA56C43),
      };

  @override
  Widget build(BuildContext context) {
    final metal = _metal;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size - 8,
            height: size - 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  metal.withValues(alpha: 0.42),
                  metal,
                  RoyalPalette.panel2,
                  metal.withValues(alpha: 0.72),
                  metal.withValues(alpha: 0.42),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: metal.withValues(alpha: 0.18),
                  blurRadius: 10,
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: RoyalPalette.nearBlack,
              ),
              child: ClipOval(child: child),
            ),
          ),
          Positioned(
            top: -8,
            child: _RoyalCrown(rank: rank, color: metal, compact: true),
          ),
          Positioned(
            bottom: -4,
            child: Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RoyalPalette.nearBlack,
                border: Border.all(color: metal),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: metal,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoyalCrown extends StatelessWidget {
  const _RoyalCrown({
    required this.rank,
    required this.color,
    this.compact = false,
  });

  final int rank;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 26.0 : 38.0;
    final height = compact ? 15.0 : 20.0;
    return CustomPaint(
      size: Size(width, height),
      painter: _RoyalCrownPainter(color, rank),
    );
  }
}

class _RoyalCrownPainter extends CustomPainter {
  const _RoyalCrownPainter(this.color, this.rank);

  final Color color;
  final int rank;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .08, size.height * .82)
      ..lineTo(size.width * .15, size.height * .30)
      ..lineTo(size.width * .36, size.height * .57)
      ..lineTo(size.width * .50, size.height * .10)
      ..lineTo(size.width * .64, size.height * .57)
      ..lineTo(size.width * .85, size.height * .30)
      ..lineTo(size.width * .92, size.height * .82)
      ..close();
    final shader = LinearGradient(
      colors: [
        color.withValues(alpha: .72),
        color,
        Colors.white.withValues(alpha: rank == 1 ? .58 : .28),
        color,
      ],
    ).createShader(Offset.zero & size);
    canvas.drawPath(path, Paint()..shader = shader);
    canvas.drawLine(
      Offset(size.width * .10, size.height * .84),
      Offset(size.width * .90, size.height * .84),
      Paint()
        ..color = color
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _RoyalCrownPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.rank != rank;
}

class _RoyalPartyBackdropPainter extends CustomPainter {
  const _RoyalPartyBackdropPainter({
    required this.accent,
    required this.intensity,
  });

  final Color accent;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0B0806),
          Color(0xFF160F13),
          Color(0xFF080706),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final aura = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: .18 * intensity),
          accent.withValues(alpha: .04 * intensity),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .74, size.height * .42),
          radius: size.width * .48,
        ),
      );
    canvas.drawRect(rect, aura);

    final gold = RoyalPalette.gold.withValues(alpha: .58 * intensity);
    final line = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;

    final arch = Rect.fromCenter(
      center: Offset(size.width * .78, size.height * .58),
      width: size.width * .38,
      height: size.height * 1.15,
    );
    canvas.drawArc(arch, math.pi, math.pi, false, line);
    canvas.drawArc(
      arch.deflate(8),
      math.pi,
      math.pi,
      false,
      line..color = gold.withValues(alpha: .42),
    );

    final crownCenter = Offset(size.width * .77, size.height * .36);
    final crown = Path()
      ..moveTo(crownCenter.dx - 28, crownCenter.dy + 16)
      ..lineTo(crownCenter.dx - 24, crownCenter.dy - 14)
      ..lineTo(crownCenter.dx - 8, crownCenter.dy + 1)
      ..lineTo(crownCenter.dx, crownCenter.dy - 22)
      ..lineTo(crownCenter.dx + 8, crownCenter.dy + 1)
      ..lineTo(crownCenter.dx + 24, crownCenter.dy - 14)
      ..lineTo(crownCenter.dx + 28, crownCenter.dy + 16)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..shader = LinearGradient(
          colors: [
            RoyalPalette.deepGold,
            RoyalPalette.gold,
            Colors.white.withValues(alpha: .68),
            RoyalPalette.gold,
          ],
        ).createShader(Rect.fromCenter(center: crownCenter, width: 58, height: 42)),
    );

    final sparkle = Paint()..color = RoyalPalette.gold.withValues(alpha: .64);
    const points = <Offset>[
      Offset(.62, .18),
      Offset(.88, .18),
      Offset(.94, .50),
      Offset(.68, .70),
      Offset(.55, .52),
    ];
    for (final p in points) {
      final center = Offset(size.width * p.dx, size.height * p.dy);
      canvas.drawCircle(center, 1.4, sparkle);
      canvas.drawLine(
        center - const Offset(3.5, 0),
        center + const Offset(3.5, 0),
        sparkle..strokeWidth = .7,
      );
      canvas.drawLine(
        center - const Offset(0, 3.5),
        center + const Offset(0, 3.5),
        sparkle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoyalPartyBackdropPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.intensity != intensity;
}

class _RoyalPanelOrnamentPainter extends CustomPainter {
  const _RoyalPanelOrnamentPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: .34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;

    const inset = 7.0;
    final tl = Path()
      ..moveTo(inset, 24)
      ..quadraticBezierTo(inset, inset, 24, inset)
      ..lineTo(38, inset);
    final br = Path()
      ..moveTo(size.width - inset, size.height - 24)
      ..quadraticBezierTo(
        size.width - inset,
        size.height - inset,
        size.width - 24,
        size.height - inset,
      )
      ..lineTo(size.width - 38, size.height - inset);
    canvas.drawPath(tl, p);
    canvas.drawPath(br, p);

    final dot = Paint()..color = color.withValues(alpha: .55);
    canvas.drawCircle(const Offset(inset, inset), 1.5, dot);
    canvas.drawCircle(
      Offset(size.width - inset, size.height - inset),
      1.5,
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant _RoyalPanelOrnamentPainter oldDelegate) =>
      oldDelegate.color != color;
}
