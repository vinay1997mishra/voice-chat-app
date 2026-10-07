import 'dart:math' as math;

import 'package:flutter/material.dart';

const roomEmojis = <String>[
  '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '🥰',
  '😎', '🤩', '🥳', '😇', '🙂', '🙃', '😉', '😋',
  '😜', '🤪', '🤗', '🤭', '🫣', '🤔', '🫡', '😴',
  '😭', '🥺', '😢', '😡', '🤬', '😱', '😳', '🫠',
  '❤️', '🩷', '💖', '💕', '💞', '💔', '🔥', '✨',
  '🎉', '🎊', '🎁', '👑', '🌹', '🌟', '💯', '⚡',
  '👍', '👎', '👏', '🙌', '🙏', '🤝', '💪', '✌️',
  '👌', '🤟', '🤘', '👋', '💋', '🫶', '💃', '🕺',
];

enum EmojiEffect { laugh, love, tears, anger, surprise, sleepy, fire, sparkle, party, wave, dance, pulse }

EmojiEffect emojiEffectFor(String emoji) {
  if (const {'😀', '😁', '😂', '🤣', '😊', '🙂', '😋', '😜', '🤪', '🤭'}.contains(emoji)) {
    return EmojiEffect.laugh;
  }
  if (const {'😍', '😘', '🥰', '🤗', '❤️', '🩷', '💖', '💕', '💞', '💋', '🫶', '🌹'}.contains(emoji)) {
    return EmojiEffect.love;
  }
  if (const {'😭', '🥺', '😢', '💔'}.contains(emoji)) return EmojiEffect.tears;
  if (const {'😡', '🤬'}.contains(emoji)) return EmojiEffect.anger;
  if (const {'😱', '😳', '🫣', '🤔', '🫡'}.contains(emoji)) return EmojiEffect.surprise;
  if (const {'😴', '🫠'}.contains(emoji)) return EmojiEffect.sleepy;
  if (const {'🔥', '⚡'}.contains(emoji)) return EmojiEffect.fire;
  if (const {'✨', '🌟', '👑', '🤩', '😇', '💯'}.contains(emoji)) return EmojiEffect.sparkle;
  if (const {'🥳', '🎉', '🎊', '🎁'}.contains(emoji)) return EmojiEffect.party;
  if (const {'👍', '👎', '👏', '🙌', '🙏', '🤝', '💪', '✌️', '👌', '🤟', '🤘', '👋'}.contains(emoji)) {
    return EmojiEffect.wave;
  }
  if (const {'💃', '🕺', '🙃', '😉', '😎'}.contains(emoji)) return EmojiEffect.dance;
  // New catalog emojis get a pulse and orbit without needing another APK.
  return EmojiEffect.pulse;
}

/// Owns one bounded-cost clock. A picker or catalog shares it between tiles.
class EmojiMotion extends StatefulWidget {
  const EmojiMotion({super.key, required this.builder});
  final Widget Function(BuildContext, Animation<double>) builder;

  @override
  State<EmojiMotion> createState() => _EmojiMotionState();
}

class _EmojiMotionState extends State<EmojiMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    final enabled = _foreground && TickerMode.of(context) &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (enabled && !_motion.isAnimating) _motion.repeat();
    if (!enabled) {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _motion);
}

class AnimatedEmoji extends StatelessWidget {
  const AnimatedEmoji({
    super.key,
    required this.emoji,
    this.size = 48,
    this.timeline,
    this.particles = true,
    this.effect,
    this.artwork,
    this.semanticLabel,
  });

  final String emoji;
  final double size;
  final Animation<double>? timeline;
  final bool particles;
  final EmojiEffect? effect;
  final Widget? artwork;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final clock = timeline;
    if (clock == null) {
      return EmojiMotion(
        builder: (context, motion) => AnimatedEmoji(
          emoji: emoji, size: size, timeline: motion, particles: particles, effect: effect,
          artwork: artwork, semanticLabel: semanticLabel,
        ),
      );
    }
    final resolvedEffect = effect ?? emojiEffectFor(emoji);
    return Semantics(
      label: semanticLabel ?? emoji,
      image: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: clock,
              child: artwork ?? Text(emoji, textAlign: TextAlign.center,
                style: TextStyle(fontSize: size * .76, height: 1)),
              builder: (context, child) {
                final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                final t = reduced ? 0.0 : clock.value;
                final wave = math.sin(t * math.pi * 2);
                var dx = 0.0, dy = 0.0, angle = 0.0, scale = 1.0;
                if (!reduced) {
                  switch (resolvedEffect) {
                    case EmojiEffect.laugh:
                      dy = -wave.abs() * size * .09;
                      scale = 1 + wave * .06;
                      angle = wave * .06;
                      break;
                    case EmojiEffect.love:
                      scale = 1 + wave * .09;
                      break;
                    case EmojiEffect.tears:
                      dy = wave * size * .025;
                      angle = wave * .04;
                      break;
                    case EmojiEffect.anger:
                      dx = math.sin(t * math.pi * 12) * size * .035;
                      angle = math.sin(t * math.pi * 8) * .045;
                      break;
                    case EmojiEffect.surprise:
                      scale = 1 + wave.abs() * .12;
                      dy = -wave.abs() * size * .035;
                      break;
                    case EmojiEffect.sleepy:
                      angle = wave * .1;
                      dy = wave * size * .035;
                      break;
                    case EmojiEffect.fire:
                      scale = 1 + math.sin(t * math.pi * 6) * .055;
                      dy = -wave.abs() * size * .035;
                      break;
                    case EmojiEffect.sparkle:
                      scale = 1 + wave * .06;
                      angle = wave * .035;
                      break;
                    case EmojiEffect.party:
                      angle = wave * .15;
                      dy = -wave.abs() * size * .07;
                      break;
                    case EmojiEffect.wave:
                      angle = wave * .22;
                      break;
                    case EmojiEffect.dance:
                      dx = wave * size * .07;
                      angle = wave * .18;
                      dy = -wave.abs() * size * .04;
                      break;
                    case EmojiEffect.pulse:
                      scale = 1 + wave * .07;
                      dy = wave * size * .025;
                      break;
                  }
                }
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (particles && !reduced)
                      Positioned.fill(child: CustomPaint(
                        painter: _EmojiParticles(effect: resolvedEffect, t: t),
                      )),
                    Transform.translate(
                      key: const ValueKey('emoji-motion-offset'),
                      offset: Offset(dx, dy),
                      child: Transform.rotate(angle: angle,
                        child: Transform.scale(scale: scale, child: child)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiParticles extends CustomPainter {
  const _EmojiParticles({required this.effect, required this.t});
  final EmojiEffect effect;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(size.width, size.height);
    final center = size.center(Offset.zero);
    final color = switch (effect) {
      EmojiEffect.love => const Color(0xFFFF73A9),
      EmojiEffect.tears => const Color(0xFF70C6FF),
      EmojiEffect.anger || EmojiEffect.fire => const Color(0xFFFF733A),
      EmojiEffect.sleepy => const Color(0xFFADAAFF),
      _ => const Color(0xFFFFD06F),
    };
    // Six small particles; no videos, blur filters or unbounded emitters.
    for (var i = 0; i < 6; i++) {
      final phase = (t + i / 6) % 1;
      final a = i * math.pi / 3 + t * math.pi * .6;
      final point = effect == EmojiEffect.tears
          ? Offset(center.dx + (i.isEven ? -.28 : .28) * unit,
              unit * (.28 + phase * .63))
          : effect == EmojiEffect.love || effect == EmojiEffect.fire || effect == EmojiEffect.sleepy
              ? Offset(unit * (.12 + i * .15), unit * (.88 - phase * .8))
              : center + Offset(math.cos(a), math.sin(a)) * unit * (.31 + phase * .13);
      final paint = Paint()..color = color.withValues(alpha: (1 - phase) * .75);
      final radius = unit * (.018 + (1 - phase) * .022);
      switch (effect) {
        case EmojiEffect.love:
          final r = radius * 1.5;
          final path = Path()..moveTo(point.dx, point.dy + r)
            ..cubicTo(point.dx - r * 2, point.dy, point.dx - r, point.dy - r * 2, point.dx, point.dy - r * .4)
            ..cubicTo(point.dx + r, point.dy - r * 2, point.dx + r * 2, point.dy, point.dx, point.dy + r);
          canvas.drawPath(path, paint);
          break;
        case EmojiEffect.tears:
          canvas.drawOval(Rect.fromCenter(center: point, width: radius * 1.5, height: radius * 3), paint);
          break;
        case EmojiEffect.anger:
        case EmojiEffect.fire:
          canvas.drawLine(point, point + Offset(radius * 2, -radius * 3),
            paint..strokeWidth = unit * .02..strokeCap = StrokeCap.round);
          break;
        case EmojiEffect.party:
          canvas.save();
          canvas.translate(point.dx, point.dy);
          canvas.rotate(a + t * 5);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 3),
            paint..color = Colors.primaries[i * 2].withValues(alpha: (1 - phase) * .8));
          canvas.restore();
          break;
        case EmojiEffect.sparkle:
        case EmojiEffect.surprise:
          canvas.drawLine(point - Offset(radius * 2, 0), point + Offset(radius * 2, 0), paint..strokeWidth = unit * .02);
          canvas.drawLine(point - Offset(0, radius * 2), point + Offset(0, radius * 2), paint);
          break;
        case EmojiEffect.sleepy:
          final label = TextPainter(text: TextSpan(text: 'z',
            style: TextStyle(fontSize: unit * .12, color: paint.color)),
            textDirection: TextDirection.ltr)..layout();
          label.paint(canvas, point);
          break;
        default:
          canvas.drawCircle(point, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EmojiParticles oldDelegate) =>
      oldDelegate.effect != effect || oldDelegate.t != t;
}
