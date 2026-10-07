import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'animated_shop_frames.dart';

class AnimatedAvatarFrame extends StatefulWidget {
  const AnimatedAvatarFrame({
    super.key,
    required this.child,
    required this.frameId,
    required this.size,
    this.avatarScale = .72,
    this.outsideOnly = false,
  });
  final Widget child;
  final String? frameId;
  final double size;
  final double avatarScale;
  final bool outsideOnly;

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
    final avatarSize = widget.size * widget.avatarScale;
    final frameCanvasSize =
        widget.outsideOnly ? avatarSize * 1.34 : widget.size;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: RepaintBoundary(
          child: SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: widget.child,
          ),
        ),
        builder: (context, avatarChild) => SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              avatarChild!,
              IgnorePointer(
                child: widget.outsideOnly
                    ? OverflowBox(
                        minWidth: frameCanvasSize,
                        maxWidth: frameCanvasSize,
                        minHeight: frameCanvasSize,
                        maxHeight: frameCanvasSize,
                        alignment: Alignment.center,
                        child: CustomPaint(
                          size: Size.square(frameCanvasSize),
                          painter: _AvatarFramePainter(
                            frame,
                            _controller.value,
                            protectedInnerRadius: avatarSize / 2,
                          ),
                        ),
                      )
                    : CustomPaint(
                        size: Size.square(widget.size),
                        painter: _AvatarFramePainter(frame, _controller.value),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarFramePainter extends CustomPainter {
  _AvatarFramePainter(
    this.id,
    this.t, {
    this.protectedInnerRadius,
  });
  final String id;
  final double t;
  final double? protectedInnerRadius;

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
    final protectedRadius = protectedInnerRadius;
    if (protectedRadius != null && protectedRadius > 0) {
      final outer = Path()..addRect(Offset.zero & size);
      final inner = Path()
        ..addOval(
          Rect.fromCircle(
            center: size.center(Offset.zero),
            radius: protectedRadius,
          ),
        );
      canvas.save();
      canvas.clipPath(
        Path.combine(PathOperation.difference, outer, inner),
      );
    }

    final shopTheme = animatedShopFrame(id);
    if (shopTheme != null) {
      _paintShopFrame(canvas, size, shopTheme);
      if (protectedRadius != null && protectedRadius > 0) {
        canvas.restore();
      }
      return;
    }
    if (id.startsWith('rocket-l')) {
      _paintRocketFrame(canvas, size);
      if (protectedRadius != null && protectedRadius > 0) {
        canvas.restore();
      }
      return;
    }
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
    if (protectedRadius != null && protectedRadius > 0) {
      canvas.restore();
    }
  }



  void _paintShopFrame(Canvas canvas, Size size, ShopFrameTheme theme) {
    final center = size.center(Offset.zero);
    final radius = size.width * .38;
    final phase = t * math.pi * 2;
    final variant = theme.variant;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final pulse = .92 + .08 * math.sin(phase * (1 + variant % 3));
    final colors = [theme.primary, theme.accent, theme.primary.withValues(alpha: .25), theme.primary];
    final shader = SweepGradient(colors: colors, transform: GradientRotation(phase * (variant.isEven ? 1 : -1))).createShader(rect);
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = size.width * .075 * pulse
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * .035)
      ..shader = shader);
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = size.width * .032..shader = shader;
    canvas.drawCircle(center, radius * pulse, ring);
    if (theme.category == 'simple') {
      final count = 2 + variant;
      for (var i = 0; i < count; i++) {
        final a = phase * (1 + variant * .15) + i * math.pi * 2 / count;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius * (1.06 + .015 * i)),
          a, math.pi / (3 + variant), false, Paint()..color = theme.accent..style = PaintingStyle.stroke..strokeWidth = size.width * .015);
        final dot = center + Offset(math.cos(a), math.sin(a)) * radius;
        canvas.drawCircle(dot, size.width * (.012 + variant * .002), Paint()..color = theme.accent);
      }
      return;
    }
    final love = theme.category == 'love';
    final funny = theme.category == 'funny';
    final count = love ? 4 + variant % 3 : funny ? 3 + variant % 3 : 6;
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count + (funny ? math.sin(phase) * .13 : phase * .12);
      final drift = love ? .03 * math.sin(phase * 2 + i) : .07 * math.sin(phase * 3 + i);
      final p = center + Offset(math.cos(a), math.sin(a)) * radius * (1.07 + drift);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate((funny ? .18 : .07) * math.sin(phase * 2 + i));
      final painter = TextPainter(
        text: TextSpan(text: theme.motif, style: TextStyle(fontSize: size.width * (funny ? .14 : .12))),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
    final particles = love ? 8 : 10 + variant % 5;
    for (var i = 0; i < particles; i++) {
      final travel = (t + i / particles) % 1;
      final a = i * math.pi * 2 / particles + phase * .16;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius * (1.03 + travel * .25);
      final color = (i.isEven ? theme.primary : theme.accent).withValues(alpha: 1 - travel);
      if (love) {
        final h = size.width * .025 * (1 - travel * .5);
        final heart = Path()..moveTo(p.dx, p.dy + h)
          ..cubicTo(p.dx - h * 2, p.dy - h * .2, p.dx - h, p.dy - h * 1.4, p.dx, p.dy - h * .4)
          ..cubicTo(p.dx + h, p.dy - h * 1.4, p.dx + h * 2, p.dy - h * .2, p.dx, p.dy + h)..close();
        canvas.drawPath(heart, Paint()..color = color);
      } else if (funny) {
        canvas.save(); canvas.translate(p.dx, p.dy); canvas.rotate(phase + i);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size.width * .025, height: size.width * .055), Paint()..color = color);
        canvas.restore();
      } else {
        canvas.drawCircle(p, size.width * .015 * (1 - travel), Paint()..color = color);
      }
    }

    if (variant >= 18) {
      for (var layer = 0; layer < 2 + (variant - 18) ~/ 3; layer++) {
        final outerRadius = radius * (1.08 + layer * .055);
        canvas.drawArc(Rect.fromCircle(center: center, radius: outerRadius),
          (layer.isEven ? phase : -phase) + layer, math.pi * 1.45, false,
          Paint()..style = PaintingStyle.stroke..strokeWidth = size.width * .012
            ..color = (layer.isEven ? theme.primary : theme.accent).withValues(alpha: .7));
      }
      for (final side in [-1.0, 1.0]) {
        final wing = Path()
          ..moveTo(center.dx + side * radius, center.dy + radius * .6)
          ..quadraticBezierTo(center.dx + side * radius * (1.38 + .06 * math.sin(phase)),
            center.dy, center.dx + side * radius * .8, center.dy - radius * .7);
        canvas.drawPath(wing, Paint()..style = PaintingStyle.stroke..strokeWidth = size.width * .038
          ..color = theme.accent.withValues(alpha: .75));
      }
    }

    if (theme.category == 'royal') {
      final crown = Path()..moveTo(center.dx - radius * .35, center.dy - radius * 1.04)
        ..lineTo(center.dx - radius * .2, center.dy - radius * 1.27)
        ..lineTo(center.dx, center.dy - radius * 1.10)
        ..lineTo(center.dx + radius * .2, center.dy - radius * 1.27)
        ..lineTo(center.dx + radius * .35, center.dy - radius * 1.04)..close();
      canvas.drawPath(crown, Paint()..color = theme.accent);
    }
  }

  void _paintRocketFrame(Canvas canvas, Size size) {
    final match = RegExp(r'^rocket-l(\d+)-(top|member)(\d+)$').firstMatch(id);
    if (match == null) return;
    final level = int.parse(match.group(1)!).clamp(1, 10);
    final isTop = match.group(2) == 'top';
    final variant = int.parse(match.group(3)!);
    final accent = isTop
        ? [const Color(0xFFFFD166), const Color(0xFFD9E7F3), const Color(0xFFFFAA79)][(variant - 1).clamp(0, 2)]
        : HSVColor.fromAHSV(1, 180 + (variant - 1) * 5, .5 + (variant % 3) * .1, 1).toColor();
    final center = size.center(Offset.zero);
    final radius = size.width * .38;
    final angle = t * math.pi * 2 + (isTop ? 0 : variant * math.pi / 15);
    final rings = isTop ? 2 + level ~/ 3 : 1 + level ~/ 5;
    for (var i = 0; i < rings; i++) {
      final r = radius + i * size.width * .027;
      canvas.drawCircle(center, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (isTop ? .037 : .023)
        ..shader = SweepGradient(
          colors: [accent, const Color(0xFF182535), accent, const Color(0xFF66E5FF), accent],
          transform: GradientRotation(i.isEven ? angle : -angle),
        ).createShader(Rect.fromCircle(center: center, radius: r)));
    }
    final count = isTop ? 6 + level * 2 : 4 + level ~/ 2 + variant % 3;
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count + (isTop ? angle * .3 : 0);
      final p = center + Offset(math.cos(a), math.sin(a)) * (radius * 1.10);
      final pulse = .6 + .4 * math.sin(angle * 2 + i).abs();
      canvas.drawCircle(p, size.width * (isTop ? .025 : .014) * pulse, Paint()..color = accent);
      if (isTop && level >= 4) {
        final outer = center + Offset(math.cos(a), math.sin(a)) * (radius * 1.22);
        canvas.drawLine(p, outer, Paint()..color = accent.withValues(alpha: .7)..strokeWidth = size.width * .018);
      }
    }
    if (isTop) {
      for (final side in [-1.0, 1.0]) {
        final x = center.dx + side * radius * .97;
        final body = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, center.dy + radius * .18), width: size.width * (.07 + level * .002), height: size.width * .30),
          Radius.circular(size.width * .03));
        canvas.drawRRect(body, Paint()..color = const Color(0xFF111925));
        canvas.drawRRect(body, Paint()..style = PaintingStyle.stroke..strokeWidth = size.width * .015..color = accent);
        final flame = Path()
          ..moveTo(x - size.width * .025, center.dy + radius * .57)
          ..quadraticBezierTo(x, center.dy + radius * (.95 + .15 * math.sin(angle * 4)), x + size.width * .025, center.dy + radius * .57)
          ..close();
        canvas.drawPath(flame, Paint()..color = const Color(0xFF64DAFF));
      }
      final crown = Path()
        ..moveTo(center.dx - radius * .42, center.dy - radius * 1.03)
        ..lineTo(center.dx - radius * .25, center.dy - radius * 1.30)
        ..lineTo(center.dx, center.dy - radius * 1.12)
        ..lineTo(center.dx + radius * .25, center.dy - radius * 1.30)
        ..lineTo(center.dx + radius * .42, center.dy - radius * 1.03)..close();
      canvas.drawPath(crown, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarFramePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.id != id;
}
