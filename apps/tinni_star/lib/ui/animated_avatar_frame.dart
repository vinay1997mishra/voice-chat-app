import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedAvatarFrame extends StatefulWidget {
  const AnimatedAvatarFrame({
    super.key,
    required this.child,
    required this.frameId,
    required this.size,
  });
  final Widget child;
  final String? frameId;
  final double size;

  @override
  State<AnimatedAvatarFrame> createState() => _AnimatedAvatarFrameState();
}

class _AnimatedAvatarFrameState extends State<AnimatedAvatarFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.frameId;
    if (frame == null || frame.isEmpty) {
      return SizedBox(width: widget.size, height: widget.size, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: widget.size * .72,
              height: widget.size * .72,
              child: widget.child,
            ),
            IgnorePointer(
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _AvatarFramePainter(frame, _controller.value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFramePainter extends CustomPainter {
  _AvatarFramePainter(this.id, this.t);
  final String id;
  final double t;

  List<Color> get colors {
    if (id.contains('fire') || id.contains('dragon')) {
      return const [Color(0xFFFF3D00), Color(0xFFFFD740), Color(0xFF8B0000)];
    }
    if (id.contains('ocean') || id.contains('diamond')) {
      return const [Color(0xFF00E5FF), Color(0xFF2979FF), Color(0xFFE1F5FE)];
    }
    if (id.contains('rose') || id.contains('love') || id.contains('couple')) {
      return const [Color(0xFFFF4081), Color(0xFFFF80AB), Color(0xFFFFD54F)];
    }
    if (id.contains('nature') || id.contains('butterfly')) {
      return const [Color(0xFF69F0AE), Color(0xFF00BFA5), Color(0xFFFFD740)];
    }
    if (id.contains('galaxy')) {
      return const [Color(0xFF7C4DFF), Color(0xFF00E5FF), Color(0xFFE040FB)];
    }
    if (id.contains('music')) {
      return const [Color(0xFFE040FB), Color(0xFF00E5FF), Color(0xFFFF4081)];
    }
    return const [Color(0xFFFFD740), Color(0xFFFF8F00), Color(0xFFFFF8E1)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * .38;
    final palette = colors;
    final rotation = t * math.pi * 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .10
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * .055)
      ..shader = SweepGradient(
        colors: [...palette, palette.first],
        transform: GradientRotation(rotation),
      ).createShader(rect);
    canvas.drawCircle(c, r, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .045
      ..shader = SweepGradient(
        colors: [...palette, palette.first],
        transform: GradientRotation(rotation),
      ).createShader(rect);
    canvas.drawCircle(c, r, ring);

    final sparkle = Paint()..color = palette.last;
    for (var i = 0; i < 6; i++) {
      final a = rotation + i * math.pi / 3;
      final pulse = .75 + .25 * math.sin(rotation * 2 + i);
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * 1.05);
      canvas.drawCircle(p, size.width * .022 * pulse, sparkle);
    }

    if (id.contains('royal') || id.contains('princess') || id.contains('vip')) {
      final crown = Path()
        ..moveTo(c.dx - r * .42, c.dy - r * 1.04)
        ..lineTo(c.dx - r * .25, c.dy - r * 1.34)
        ..lineTo(c.dx, c.dy - r * 1.08)
        ..lineTo(c.dx + r * .25, c.dy - r * 1.34)
        ..lineTo(c.dx + r * .42, c.dy - r * 1.04)
        ..close();
      canvas.drawPath(crown, Paint()..color = palette.first);
    }
    if (id.contains('angel') || id.contains('swan') || id.contains('butterfly')) {
      final wing = Paint()
        ..color = palette.last.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .035;
      final flap = math.sin(rotation) * r * .10;
      canvas.drawArc(
        Rect.fromCenter(center: c + Offset(-r * .75, flap), width: r, height: r * 1.25),
        math.pi * .65, math.pi * .75, false, wing);
      canvas.drawArc(
        Rect.fromCenter(center: c + Offset(r * .75, flap), width: r, height: r * 1.25),
        math.pi * 1.6, math.pi * .75, false, wing);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarFramePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.id != id;
}
