import 'dart:math' as math;

import 'package:flutter/material.dart';

enum GiftAtmosphereKind {
  petals, jewels, hotFood, glaze, dessert, goldDragon, fireDragon, iceDragon, bird, architecture, water, leaves, cosmos, butterfly, wildlife, vehicle, lanterns, meteors, romance, balloons, candy, treasure, music, flag,
}

/// Foreground weather and heat over the local movies, using the delivery clock.
/// No network, extra decoder, timers, or changes to gift settlement.
class GiftAtmosphere extends StatelessWidget {
  const GiftAtmosphere({
    super.key,
    required this.giftId,
    required this.progress,
    required this.child,
    this.reducedMotion = false,
  });

  final String giftId;
  final double progress;
  final Widget child;
  final bool reducedMotion;

  static const profiles = <String, GiftAtmosphereKind>{
    'royal-opera': GiftAtmosphereKind.music,
    'rose': GiftAtmosphereKind.petals,
    'rose-bouquet': GiftAtmosphereKind.petals,
    'infinity-rose': GiftAtmosphereKind.petals,
    'galaxy-garden': GiftAtmosphereKind.petals,
    'cp-rose-proposal': GiftAtmosphereKind.petals,
    'cp-garden-romance': GiftAtmosphereKind.petals,
    'lucky-colorful-rose': GiftAtmosphereKind.petals,
    'crystal': GiftAtmosphereKind.jewels,
    'crown': GiftAtmosphereKind.jewels,
    'diamond-crown': GiftAtmosphereKind.jewels,
    'emerald-ring': GiftAtmosphereKind.jewels,
    'solar-crown': GiftAtmosphereKind.jewels,
    'cp-love-ring': GiftAtmosphereKind.jewels,
    'cp-diamond-promise': GiftAtmosphereKind.jewels,
    'lucky-sparkle-crown': GiftAtmosphereKind.jewels,
    'hot-biryani': GiftAtmosphereKind.hotFood,
    'steaming-dim-sum': GiftAtmosphereKind.hotFood,
    'royal-saffron-feast': GiftAtmosphereKind.hotFood,
    'chocolate-fountain': GiftAtmosphereKind.glaze,
    'sushi-palace': GiftAtmosphereKind.glaze,
    'royal-cake': GiftAtmosphereKind.dessert,
    'cp-anniversary-cake': GiftAtmosphereKind.dessert,
    'lucky-dream-cake': GiftAtmosphereKind.dessert,
    'golden-dragon': GiftAtmosphereKind.goldDragon,
    'dragon-empire': GiftAtmosphereKind.goldDragon,
    'fire-dragon': GiftAtmosphereKind.fireDragon,
    'ice-dragon': GiftAtmosphereKind.iceDragon,
    'phoenix': GiftAtmosphereKind.bird,
    'phoenix-kingdom': GiftAtmosphereKind.bird,
    'golden-peacock': GiftAtmosphereKind.bird,
    'star-castle': GiftAtmosphereKind.architecture,
    'moon-palace': GiftAtmosphereKind.architecture,
    'golden-temple': GiftAtmosphereKind.architecture,
    'rainbow-castle': GiftAtmosphereKind.architecture,
    'cloud-kingdom': GiftAtmosphereKind.architecture,
    'crystal-palace': GiftAtmosphereKind.architecture,
    'cp-valentine-palace': GiftAtmosphereKind.architecture,
    'crystal-swan': GiftAtmosphereKind.water,
    'diamond-yacht': GiftAtmosphereKind.water,
    'rainbow-waterfall': GiftAtmosphereKind.water,
    'ocean-pearl': GiftAtmosphereKind.water,
    'diamond-fountain': GiftAtmosphereKind.water,
    'galaxy-whale': GiftAtmosphereKind.water,
    'cp-heart-fountain': GiftAtmosphereKind.water,
    'cp-beach-wedding': GiftAtmosphereKind.water,
    'enchanted-forest': GiftAtmosphereKind.leaves,
    'aurora': GiftAtmosphereKind.cosmos,
    'celestial-horse': GiftAtmosphereKind.cosmos,
    'diamond-universe': GiftAtmosphereKind.cosmos,
    'ultimate-galaxy': GiftAtmosphereKind.cosmos,
    'cp-moonlight-date': GiftAtmosphereKind.cosmos,
    'cp-starlight-couple': GiftAtmosphereKind.cosmos,
    'lucky-galaxy-ring': GiftAtmosphereKind.cosmos,
    'lucky-shining-unicorn': GiftAtmosphereKind.cosmos,
    'magic-butterfly': GiftAtmosphereKind.butterfly,
    'lucky-neon-butterfly': GiftAtmosphereKind.butterfly,
    'royal-tiger': GiftAtmosphereKind.wildlife,
    'snow-leopard': GiftAtmosphereKind.wildlife,
    'golden-lion': GiftAtmosphereKind.wildlife,
    'royal-carriage': GiftAtmosphereKind.vehicle,
    'luxury-jet': GiftAtmosphereKind.vehicle,
    'space-shuttle': GiftAtmosphereKind.vehicle,
    'royal-ferrari': GiftAtmosphereKind.vehicle,
    'cp-love-carriage': GiftAtmosphereKind.vehicle,
    'sky-lanterns': GiftAtmosphereKind.lanterns,
    'meteor-shower': GiftAtmosphereKind.meteors,
    'cp-heart': GiftAtmosphereKind.romance,
    'cp-invite': GiftAtmosphereKind.romance,
    'cp-first-kiss': GiftAtmosphereKind.romance,
    'cp-royal-wedding': GiftAtmosphereKind.romance,
    'cp-hand-in-hand': GiftAtmosphereKind.romance,
    'cp-forever-hug': GiftAtmosphereKind.romance,
    'cp-twin-hearts': GiftAtmosphereKind.romance,
    'cp-eternal-vows': GiftAtmosphereKind.romance,
    'cp-infinity-love': GiftAtmosphereKind.romance,
    'lucky-rainbow-heart': GiftAtmosphereKind.romance,
    'lucky-magic-balloon': GiftAtmosphereKind.balloons,
    'lucky-candy-star': GiftAtmosphereKind.candy,
    'lucky-royal-treasure': GiftAtmosphereKind.treasure,
  };

  static GiftAtmosphereKind? kindFor(String id) =>
      id.startsWith('flag-') ? GiftAtmosphereKind.flag : profiles[id];

  static bool isDragon(String id) => id.contains('dragon');
  static bool isHotFood(String id) => const {
    'hot-biryani', 'steaming-dim-sum', 'royal-saffron-feast',
  }.contains(id);

  @override
  Widget build(BuildContext context) {
    final dragon = isDragon(giftId);
    final hotFood = isHotFood(giftId);
    final kind = kindFor(giftId);
    // Country movies already animate the exact flag cloth for their two-second hold.
    if (kind == null || kind == GiftAtmosphereKind.flag) return child;
    final t = reducedMotion ? .55 : progress.clamp(0.0, 1.0);
    return ClipRect(
      child: LayoutBuilder(builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final entrance = Curves.easeOutCubic.transform((t / .30).clamp(0.0, 1.0));
        final orbit = ((t - .30) / .55).clamp(0.0, 1.0) * math.pi * 2;
        final travel = dragon && !reducedMotion
            ? Offset(
                math.sin(orbit) * viewport.width * .075,
                -viewport.height * .75 * (1 - entrance) +
                    math.sin(orbit * 2) * viewport.height * .015,
              )
            : Offset.zero;
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              key: ValueKey('gift-sky-entrance-$giftId'),
              offset: travel,
              child: Transform.rotate(
                angle: dragon && !reducedMotion ? math.sin(orbit) * .07 : 0,
                // Feather the studio background so a flying dragon does not
                // drag a hard rectangular movie frame through the room.
                child: dragon ? ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const RadialGradient(
                    center: Alignment(0, -.12),
                    radius: .66,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, .48, 1],
                  ).createShader(bounds),
                  child: child,
                ) : child,
              ),
            ),
            CustomPaint(
              key: ValueKey(hotFood ? 'gift-hot-steam-$giftId' : 'gift-weather-$giftId'),
              painter: _AtmospherePainter(giftId: giftId, t: t, reduced: reducedMotion),
            ),
          ],
        );
      }),
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter({required this.giftId, required this.t, required this.reduced});
  final String giftId;
  final double t;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final reveal = (t / .10).clamp(0.0, 1.0);
    final fade = ((1 - t) / .10).clamp(0.0, 1.0);
    final alpha = reveal * fade;
    final kind = GiftAtmosphere.kindFor(giftId);
    if (kind == null || kind == GiftAtmosphereKind.flag) return;
    if (GiftAtmosphere.isHotFood(giftId)) {
      _steam(canvas, size, alpha);
      return;
    }
    if (!GiftAtmosphere.isDragon(giftId)) {
      _namedScene(canvas, size, alpha, kind);
      return;
    }
    final ice = giftId == 'ice-dragon';
    final fire = giftId == 'fire-dragon';
    final glow = ice ? const Color(0xFFBDEBFF) :
        fire ? const Color(0xFFFF7D35) : const Color(0xFFFFD98F);
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          glow.withValues(alpha: .12 * alpha),
          Colors.transparent,
          glow.withValues(alpha: .14 * alpha),
        ],
        stops: const [0, .55, 1],
      ).createShader(bounds));
    _clouds(canvas, size, alpha, ice);
    _vortex(canvas, size, glow, alpha);
    if (ice) {
      _iceGround(canvas, size, alpha);
      _snow(canvas, size, alpha);
    } else {
      _embers(canvas, size, glow, alpha);
    }
  }

  void _steam(Canvas canvas, Size size, double alpha) {
    // The bowl surface in the bundled 360x640 movie lies below the center.
    // Its room viewport is 72% wide and 62% high for the three hot dishes.
    final center = Offset(size.width * .5, size.height * .535);
    final radius = math.min(size.width * .115, size.height * .058);
    final warm = Rect.fromCenter(center: center, width: radius * 4, height: radius * 2);
    canvas.drawOval(warm, Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFFCF83).withValues(alpha: .09 * alpha), Colors.transparent,
      ]).createShader(warm));
    for (var i = 0; i < 9; i++) {
      final phase = (t * 2.1 + i * .137) % 1;
      final height = size.height * (.11 + .055 * (i % 3));
      final x = center.dx + (i - 4) * radius * .20;
      final lift = phase * height * .35;
      final sway = math.sin(t * 9 + i * 1.7) * radius * .30;
      final path = Path()
        ..moveTo(x, center.dy - lift)
        ..cubicTo(x - radius * .20, center.dy - height * .25 - lift,
            x + sway, center.dy - height * .55 - lift,
            x + sway * 1.5, center.dy - height - lift);
      final opacity = alpha * .30 * math.sin(phase * math.pi);
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3 + (i % 3) * 1.5
        ..color = const Color(0xFFF4F7FA).withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: opacity * .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8));
    }
  }

  void _clouds(Canvas canvas, Size size, double alpha, bool ice) {
    final cloud = ice ? const Color(0xFFE7F5FF) : const Color(0xFFBCC9DE);
    for (var i = 0; i < 10; i++) {
      final phase = (i / 10 + t * .20) % 1;
      final x = (phase * 1.4 - .20) * size.width;
      final y = size.height * (.06 + (i % 3) * .075);
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: size.width * (.40 + (i % 2) * .16),
        height: size.height * .07,
      );
      canvas.drawOval(rect, Paint()
        ..shader = RadialGradient(colors: [
          cloud.withValues(alpha: alpha * .16), Colors.transparent,
        ]).createShader(rect));
    }
    final fog = Rect.fromLTWH(0, size.height * .72, size.width, size.height * .28);
    canvas.drawRect(fog, Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter, end: Alignment.topCenter,
        colors: [cloud.withValues(alpha: alpha * .13), Colors.transparent],
      ).createShader(fog));
  }

  void _vortex(Canvas canvas, Size size, Color glow, double alpha) {
    final center = Offset(size.width * .5, size.height * .43);
    final radius = math.min(size.width * .41, size.height * .27);
    for (var i = 0; i < 3; i++) {
      final oval = Rect.fromCenter(
        center: center + Offset(0, (i - 1) * radius * .12),
        width: radius * (2 - i * .12), height: radius * .62,
      );
      canvas.drawArc(oval, t * math.pi * 4 + i * 2, math.pi * .85, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = glow.withValues(alpha: .40 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
    final halo = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()
      ..shader = RadialGradient(colors: [
        Colors.transparent, glow.withValues(alpha: .04 * alpha),
        glow.withValues(alpha: .09 * alpha), Colors.transparent,
      ], stops: const [0, .60, .81, 1]).createShader(halo));
  }

  void _iceGround(Canvas canvas, Size size, double alpha) {
    final frost = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * .90)
      ..quadraticBezierTo(size.width * .25, size.height * .84, size.width * .48, size.height * .91)
      ..quadraticBezierTo(size.width * .72, size.height * .97, size.width, size.height * .87)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(frost, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE9F9FF).withValues(alpha: .62 * alpha),
          const Color(0xFF5686AE).withValues(alpha: .35 * alpha),
        ],
      ).createShader(Offset.zero & size));
    for (var i = 0; i < 9; i++) {
      final x = (i + .5) / 9 * size.width;
      final height = size.height * (.035 + (i % 3) * .014);
      final crystal = Path()
        ..moveTo(x - height * .18, size.height * .95)
        ..lineTo(x, size.height * .95 - height)
        ..lineTo(x + height * .21, size.height * .95)
        ..close();
      canvas.drawPath(crystal, Paint()
        ..color = const Color(0xFFD1F2FF).withValues(alpha: .46 * alpha));
    }
  }

  void _snow(Canvas canvas, Size size, double alpha) {
    // Fixed seeds avoid flicker; three speeds give foreground/background depth.
    final speed = reduced ? 0.0 : t * 2.8;
    for (var i = 0; i < 64; i++) {
      final depth = i % 3;
      final seed = (i * .61803398875) % 1;
      final y = ((seed + speed * (.15 + depth * .12)) % 1) * size.height;
      final x = (((i * .38196601125) % 1) * size.width +
          math.sin(t * 8 + i) * (6 + depth * 5)) % size.width;
      final radius = .8 + depth * .75;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * (.35 + depth * .22));
      if (depth == 2) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, .6);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _embers(Canvas canvas, Size size, Color glow, double alpha) {
    for (var i = 0; i < 32; i++) {
      final phase = (i * .618 + t * 1.2) % 1;
      final x = ((i * .382) % 1) * size.width +
          math.sin(t * 9 + i) * size.width * .03;
      final y = size.height * (1 - phase);
      canvas.drawCircle(Offset(x, y), .8 + (i % 3) * .7, Paint()
        ..color = glow.withValues(alpha: alpha * .60 * math.sin(phase * math.pi)));
    }
  }


  Color _accent(GiftAtmosphereKind kind) {
    if (giftId.contains('emerald') || kind == GiftAtmosphereKind.leaves) {
      return const Color(0xFF78E9AA);
    }
    if (giftId.contains('rainbow') || giftId.contains('aurora')) return const Color(0xFF9CDDFF);
    if (giftId.contains('chocolate')) return const Color(0xFFC48454);
    if (giftId.contains('solar') || giftId.contains('golden')) return const Color(0xFFFFD26D);
    return switch (kind) {
      GiftAtmosphereKind.petals || GiftAtmosphereKind.romance || GiftAtmosphereKind.dessert =>
        const Color(0xFFFFA8CF),
      GiftAtmosphereKind.water || GiftAtmosphereKind.cosmos || GiftAtmosphereKind.butterfly =>
        const Color(0xFF8CDFFF),
      GiftAtmosphereKind.bird => const Color(0xFFFFA764),
      _ => const Color(0xFFFFDE9A),
    };
  }

  void _namedScene(Canvas canvas, Size size, double alpha, GiftAtmosphereKind kind) {
    final color = _accent(kind);
    final center = Offset(size.width * .5, size.height * .43);
    final glow = Rect.fromCircle(center: center, radius: size.width * .40);
    canvas.drawCircle(center, size.width * .40, Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: .045 * alpha), Colors.transparent,
      ]).createShader(glow));
    switch (kind) {
      case GiftAtmosphereKind.petals:
        _petals(canvas, size, color, alpha, leaves: false);
        if (giftId == 'galaxy-garden') _stars(canvas, size, color, alpha);
      case GiftAtmosphereKind.jewels:
        _glints(canvas, size, color, alpha);
        _rings(canvas, size, color, alpha);
      case GiftAtmosphereKind.glaze:
        if (giftId == 'chocolate-fountain') {
          _water(canvas, size, color, alpha, chocolate: true);
        } else {
          _glints(canvas, size, const Color(0xFFFFC1A0), alpha * .55);
        }
      case GiftAtmosphereKind.dessert:
        _glints(canvas, size, color, alpha);
        _confetti(canvas, size, alpha);
      case GiftAtmosphereKind.bird:
        if (giftId.contains('phoenix')) {
          _embers(canvas, size, color, alpha);
          _vortex(canvas, size, color, alpha);
        } else {
          _glints(canvas, size, const Color(0xFF7DEEC6), alpha);
          _rings(canvas, size, color, alpha);
        }
      case GiftAtmosphereKind.architecture:
        _glints(canvas, size, color, alpha);
        _rays(canvas, size, color, alpha);
        if (giftId.contains('cloud')) _clouds(canvas, size, alpha, false);
        if (giftId.contains('moon') || giftId.contains('star')) _stars(canvas, size, color, alpha);
      case GiftAtmosphereKind.water:
        _water(canvas, size, color, alpha);
        if (giftId.contains('galaxy')) _stars(canvas, size, color, alpha);
      case GiftAtmosphereKind.leaves:
        _petals(canvas, size, color, alpha, leaves: true);
        _fireflies(canvas, size, alpha);
      case GiftAtmosphereKind.cosmos:
        _stars(canvas, size, color, alpha);
        _rings(canvas, size, color, alpha);
        if (giftId == 'aurora') _aurora(canvas, size, alpha);
      case GiftAtmosphereKind.butterfly:
        _butterflies(canvas, size, color, alpha);
      case GiftAtmosphereKind.wildlife:
        if (giftId == 'snow-leopard') {
          _snow(canvas, size, alpha);
          _iceGround(canvas, size, alpha);
        } else {
          _petals(canvas, size, const Color(0xFF94C977), alpha * .6, leaves: true);
          _rays(canvas, size, color, alpha);
        }
      case GiftAtmosphereKind.vehicle:
        _speedTrails(canvas, size, color, alpha);
        if (giftId.contains('jet') || giftId.contains('shuttle')) {
          _clouds(canvas, size, alpha, false);
        } else {
          _glints(canvas, size, color, alpha * .6);
        }
      case GiftAtmosphereKind.lanterns:
        _lanterns(canvas, size, color, alpha);
      case GiftAtmosphereKind.meteors:
        _meteors(canvas, size, color, alpha);
      case GiftAtmosphereKind.romance:
        _hearts(canvas, size, color, alpha);
        if (giftId.contains('wedding') || giftId.contains('vows')) _confetti(canvas, size, alpha);
      case GiftAtmosphereKind.balloons:
        _balloons(canvas, size, alpha);
      case GiftAtmosphereKind.candy:
        _confetti(canvas, size, alpha);
        _glints(canvas, size, color, alpha);
      case GiftAtmosphereKind.treasure:
        _coins(canvas, size, color, alpha);
        _rays(canvas, size, color, alpha);
      case GiftAtmosphereKind.music:
        _music(canvas, size, color, alpha);
      case GiftAtmosphereKind.hotFood:
      case GiftAtmosphereKind.goldDragon:
      case GiftAtmosphereKind.fireDragon:
      case GiftAtmosphereKind.iceDragon:
      case GiftAtmosphereKind.flag:
        break;
    }
    if (giftId.startsWith('cp-') && kind != GiftAtmosphereKind.romance) {
      _hearts(canvas, size, const Color(0xFFFFA8CF), alpha * .55);
    }
  }

  int get _seed => giftId.codeUnits.fold<int>(0, (value, unit) => (value * 31 + unit) & 0x7fffffff);

  double _phase(int i, double speed) => (i * .61803398875 + (_seed % 97) / 97 + t * speed) % 1;

  void _petals(Canvas canvas, Size size, Color color, double alpha, {required bool leaves}) {
    for (var i = 0; i < 18; i++) {
      final phase = _phase(i, .95);
      final y = (phase * 1.15 - .10) * size.height;
      final x = ((i * .382 + _seed / 1000) % 1) * size.width +
          math.sin(t * 8 + i) * size.width * .055;
      final r = 3.0 + i % 4;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 6 + i);
      final petal = Path()
        ..moveTo(-r, 0)
        ..quadraticBezierTo(-r, -r * 1.8, r, -r * .3)
        ..quadraticBezierTo(r * .6, r * 1.3, -r, 0);
      final rect = Rect.fromLTWH(-r, -r * 1.8, r * 2, r * 3);
      canvas.drawPath(petal, Paint()
        ..shader = LinearGradient(colors: [
          color.withValues(alpha: .58 * alpha),
          (leaves ? const Color(0xFF28734B) : const Color(0xFFCE4D83)).withValues(alpha: .34 * alpha),
        ]).createShader(rect));
      if (leaves) {
        canvas.drawLine(Offset(-r, 0), Offset(r, -r * .3),
          Paint()..color = const Color(0xFFB8F8C4).withValues(alpha: alpha * .4)..strokeWidth = .6);
      }
      canvas.restore();
    }
  }

  void _glints(Canvas canvas, Size size, Color color, double alpha) {
    for (var i = 0; i < 14; i++) {
      final phase = _phase(i, .7);
      final a = i * 2.399 + t * .8;
      final r = size.width * (.20 + (i % 4) * .055);
      final center = Offset(size.width * .5 + math.cos(a) * r,
          size.height * .43 + math.sin(a) * r * .82);
      final extent = (3 + i % 4) * math.sin(phase * math.pi);
      final star = Path()
        ..moveTo(center.dx, center.dy - extent)
        ..lineTo(center.dx + extent * .23, center.dy - extent * .23)
        ..lineTo(center.dx + extent, center.dy)
        ..lineTo(center.dx + extent * .23, center.dy + extent * .23)
        ..lineTo(center.dx, center.dy + extent)
        ..lineTo(center.dx - extent * .23, center.dy + extent * .23)
        ..lineTo(center.dx - extent, center.dy)
        ..lineTo(center.dx - extent * .23, center.dy - extent * .23)
        ..close();
      canvas.drawPath(star, Paint()..color = color.withValues(alpha: alpha * .75));
    }
  }

  void _rings(Canvas canvas, Size size, Color color, double alpha) {
    for (var i = 0; i < 3; i++) {
      final phase = _phase(i, .45);
      final radius = size.width * (.16 + phase * .26);
      final oval = Rect.fromCenter(center: Offset(size.width * .5, size.height * .49),
        width: radius * 2, height: radius * .7);
      canvas.drawArc(oval, t * 3 + i, math.pi * 1.4, false, Paint()
        ..color = color.withValues(alpha: (1 - phase) * .23 * alpha)
        ..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }
  }

  void _stars(Canvas canvas, Size size, Color color, double alpha) {
    for (var i = 0; i < 40; i++) {
      final phase = _phase(i, .6);
      final center = Offset(((i * .382 + _seed / 1000) % 1) * size.width,
        ((i * .618) % 1) * size.height * .8);
      canvas.drawCircle(center, .7 + i % 3 * .45, Paint()
        ..color = color.withValues(alpha: (.12 + .55 * math.sin(phase * math.pi)) * alpha));
    }
  }

  void _hearts(Canvas canvas, Size size, Color color, double alpha) {
    for (var i = 0; i < 12; i++) {
      final phase = _phase(i, .8);
      final r = 3.0 + i % 4;
      final x = ((i * .382) % 1) * size.width +
          math.sin(t * 7 + i) * size.width * .025;
      final y = size.height * (.85 - phase * .75);
      final path = Path()
        ..moveTo(x, y + r)
        ..cubicTo(x - r * 2, y - r * .2, x - r, y - r * 2, x, y - r * .7)
        ..cubicTo(x + r, y - r * 2, x + r * 2, y - r * .2, x, y + r);
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: alpha * .55 * math.sin(phase * math.pi)));
    }
  }

  void _water(Canvas canvas, Size size, Color color, double alpha, {bool chocolate = false}) {
    final center = Offset(size.width * .5, size.height * .59);
    for (var i = 0; i < 4; i++) {
      final phase = _phase(i, .7);
      final oval = Rect.fromCenter(center: center,
        width: size.width * (.15 + phase * .66), height: size.height * (.015 + phase * .07));
      canvas.drawOval(oval, Paint()
        ..style = PaintingStyle.stroke..strokeWidth = 1.2
        ..color = color.withValues(alpha: .28 * (1 - phase) * alpha));
    }
    for (var i = 0; i < 16; i++) {
      final phase = _phase(i, 1.1);
      final x = center.dx + math.sin(i * 2.399) * size.width * .23 * phase;
      final y = center.dy - math.sin(phase * math.pi) * size.height * .11;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 2.2, height: chocolate ? 4 : 3),
        Paint()..color = color.withValues(alpha: alpha * .38 * (1 - phase)));
    }
  }

  void _rays(Canvas canvas, Size size, Color color, double alpha) {
    final source = Offset(size.width * .5, size.height * .16);
    for (var i = 0; i < 7; i++) {
      final angle = (i - 3) * .21 + math.sin(t * 2) * .06;
      final ray = Path()..moveTo(source.dx, source.dy)
        ..lineTo(source.dx + math.sin(angle - .028) * size.height, size.height * .83)
        ..lineTo(source.dx + math.sin(angle + .028) * size.height, size.height * .83)..close();
      canvas.drawPath(ray, Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .065 * alpha), Colors.transparent]).createShader(Offset.zero & size));
    }
  }

  void _confetti(Canvas canvas, Size size, double alpha) {
    const colors = [Color(0xFFFFB6D8), Color(0xFFFFDA82), Color(0xFF9EDBFF), Color(0xFFB9F0CF)];
    for (var i = 0; i < 22; i++) {
      final phase = _phase(i, .85);
      canvas.save();
      canvas.translate(((i * .382) % 1) * size.width, phase * size.height * .88);
      canvas.rotate(i + t * 9);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-1, -3, 2, 6), const Radius.circular(.5)),
        Paint()..color = colors[i % colors.length].withValues(alpha: alpha * .55));
      canvas.restore();
    }
  }

  void _fireflies(Canvas canvas, Size size, double alpha) {
    for (var i = 0; i < 18; i++) {
      final phase = _phase(i, .6);
      final center = Offset(((i * .382) % 1) * size.width + math.sin(t * 8 + i) * 9,
        size.height * (.30 + ((i * .618) % 1) * .5) + math.cos(t * 6 + i) * 7);
      canvas.drawCircle(center, 1.5, Paint()
        ..color = const Color(0xFFD6FF9B).withValues(alpha: alpha * .6 * math.sin(phase * math.pi))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2));
    }
  }

  void _aurora(Canvas canvas, Size size, double alpha) {
    for (var i = 0; i < 5; i++) {
      final path = Path()..moveTo(0, size.height * (.08 + i * .025));
      for (var x = 0.0; x <= size.width; x += size.width / 16) {
        path.lineTo(x, size.height * (.10 + i * .025 + math.sin(x / size.width * 8 + t * 4 + i * .3) * .035));
      }
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 10
        ..color = (i.isEven ? const Color(0xFF7AFFCA) : const Color(0xFFA399FF)).withValues(alpha: .10 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    }
  }

  void _butterflies(Canvas canvas, Size size, Color color, double alpha) {
    for (var i = 0; i < 6; i++) {
      final phase = _phase(i, .7);
      final center = Offset(((i * .382) % 1) * size.width + math.sin(t * 7 + i) * 14,
        size.height * (.80 - phase * .65));
      final flap = .35 + math.sin(t * 28 + i).abs() * .65;
      for (final side in [-1.0, 1.0]) {
        canvas.drawOval(Rect.fromCenter(center: center + Offset(side * 3 * flap, -2),
          width: 6 * flap, height: 8), Paint()..color = color.withValues(alpha: alpha * .58));
      }
      canvas.drawLine(center + const Offset(0, -4), center + const Offset(0, 4),
        Paint()..color = Colors.white.withValues(alpha: alpha * .5)..strokeWidth = 1);
    }
  }

  void _speedTrails(Canvas canvas, Size size, Color color, double alpha) {
    for (var i = 0; i < 12; i++) {
      final phase = _phase(i, 2.5);
      final y = size.height * (.35 + i % 4 * .06);
      final x = size.width * (1.2 - phase * 1.4);
      final rect = Rect.fromLTWH(x, y, size.width * .14, 1.3);
      canvas.drawRect(rect, Paint()
        ..shader = LinearGradient(colors: [
          Colors.transparent, color.withValues(alpha: alpha * .28), Colors.transparent,
        ]).createShader(rect));
    }
  }

  void _lanterns(Canvas canvas, Size size, Color color, double alpha) {
    for (var i = 0; i < 8; i++) {
      final phase = _phase(i, .6);
      final center = Offset(((i * .382) % 1) * size.width, size.height * (.91 - phase * .80));
      final r = 4.0 + i % 3;
      final rect = Rect.fromCenter(center: center, width: r * 1.5, height: r * 2);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * .4)), Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFEDD4).withValues(alpha: .65 * alpha),
          color.withValues(alpha: .20 * alpha),
        ]).createShader(rect));
    }
  }

  void _meteors(Canvas canvas, Size size, Color color, double alpha) {
    _stars(canvas, size, color, alpha * .55);
    for (var i = 0; i < 8; i++) {
      final phase = _phase(i, 1.4);
      final tip = Offset(((i * .382 + phase * .22) % 1) * size.width, phase * size.height * .8);
      canvas.drawLine(tip - Offset(size.width * .06, size.height * .08), tip,
        Paint()..strokeWidth = 1.6..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: alpha * .55 * math.sin(phase * math.pi)));
      canvas.drawCircle(tip, 1.5, Paint()..color = Colors.white.withValues(alpha: alpha * .7));
    }
  }

  void _balloons(Canvas canvas, Size size, double alpha) {
    const colors = [Color(0xFF81DFFF), Color(0xFFFFA5D7), Color(0xFFCEB4FF)];
    for (var i = 0; i < 7; i++) {
      final phase = _phase(i, .7);
      final center = Offset(((i * .382) % 1) * size.width + math.sin(t * 4 + i) * 8,
        size.height * (.98 - phase * .9));
      final rect = Rect.fromCenter(center: center, width: 12, height: 16);
      canvas.drawOval(rect, Paint()
        ..shader = RadialGradient(center: const Alignment(-.4, -.4), colors: [
          Colors.white.withValues(alpha: .7 * alpha), colors[i % 3].withValues(alpha: .5 * alpha),
        ]).createShader(rect));
      final string = Path()..moveTo(center.dx, center.dy + 8)
        ..quadraticBezierTo(center.dx - 4, center.dy + 20, center.dx + 2, center.dy + 32);
      canvas.drawPath(string, Paint()..style = PaintingStyle.stroke..strokeWidth = .7
        ..color = Colors.white.withValues(alpha: alpha * .25));
    }
  }

  void _coins(Canvas canvas, Size size, Color color, double alpha) {
    for (var i = 0; i < 16; i++) {
      final phase = _phase(i, 1);
      final center = Offset(((i * .382) % 1) * size.width, phase * size.height * .82);
      final width = 2 + math.sin(t * 12 + i).abs() * 5;
      final rect = Rect.fromCenter(center: center, width: width, height: 8);
      canvas.drawOval(rect, Paint()
        ..shader = LinearGradient(colors: [
          const Color(0xFFFFF2BE).withValues(alpha: alpha * .7), color.withValues(alpha: alpha * .45),
        ]).createShader(rect));
      canvas.drawOval(rect, Paint()..style = PaintingStyle.stroke..strokeWidth = .7
        ..color = const Color(0xFFB48025).withValues(alpha: alpha * .55));
    }
  }

  void _music(Canvas canvas, Size size, Color color, double alpha) {
    for (var i = 0; i < 8; i++) {
      final phase = _phase(i, .8);
      final x = ((i * .382) % 1) * size.width;
      final y = size.height * (.83 - phase * .6);
      final paint = Paint()..color = color.withValues(alpha: alpha * .5);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 6, height: 4), paint);
      canvas.drawLine(Offset(x + 3, y), Offset(x + 3, y - 13),
        Paint()..color = paint.color..strokeWidth = 1.2);
      canvas.drawArc(Rect.fromLTWH(x + 3, y - 14, 6, 6), -math.pi / 2, math.pi / 2, false,
        Paint()..color = paint.color..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.giftId != giftId || oldDelegate.t != t || oldDelegate.reduced != reduced;
}
