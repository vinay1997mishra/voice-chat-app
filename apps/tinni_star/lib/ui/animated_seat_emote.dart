import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'animated_emoji.dart';
import 'seat_emote_catalog.dart';

class AnimatedSeatEmote extends StatelessWidget {
  const AnimatedSeatEmote({super.key, required this.emote, this.size = 64, this.timeline});
  final String emote;
  final double size;
  final Animation<double>? timeline;

  @override
  Widget build(BuildContext context) {
    final definition = seatEmoteFor(emote);
    if (definition == null) return AnimatedEmoji(emoji: emote, size: size, timeline: timeline);
    final clock = timeline;
    if (clock == null) {
      return EmojiMotion(builder: (context, motion) =>
        AnimatedSeatEmote(emote: emote, size: size, timeline: motion));
    }
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final panda = definition.group == SeatEmoteGroup.panda;
    return AnimatedEmoji(
      emoji: panda ? '🐼' : definition.glyph,
      semanticLabel: definition.name,
      size: size, timeline: clock, effect: definition.effect, particles: panda,
      artwork: SizedBox(
        width: size, height: size,
        child: CustomPaint(
          key: ValueKey('seat-emote-art-$emote'),
          painter: panda
              ? _PandaFacePainter(definition: definition, timeline: clock, reduced: reduced)
              : _EnemyEmotePainter(definition: definition, timeline: clock, reduced: reduced),
        ),
      ),
    );
  }
}

abstract class _EmotePainter extends CustomPainter {
  _EmotePainter({required this.definition, required this.timeline, required this.reduced})
      : super(repaint: timeline);
  final SeatEmoteDefinition definition;
  final Animation<double> timeline;
  final bool reduced;
  double get t => reduced ? 0 : timeline.value;

  void glyph(Canvas canvas, String text, Offset center, double fontSize) {
    final label = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
  }

  @override
  bool shouldRepaint(covariant _EmotePainter oldDelegate) =>
      oldDelegate.definition.id != definition.id || oldDelegate.reduced != reduced ||
      oldDelegate.timeline != timeline;
}

class _PandaFacePainter extends _EmotePainter {
  _PandaFacePainter({required super.definition, required super.timeline, required super.reduced});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final black = Paint()..color = const Color(0xFF18202B);
    final white = Paint()..color = const Color(0xFFFFFAF0);
    final eye = Paint()..color = Colors.white;
    final expression = definition.expression;
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(s * (.5 + side * .27), s * .25), s * .15, black);
    }
    canvas.drawOval(Rect.fromLTWH(s * .15, s * .18, s * .7, s * .64), white);
    final blink = !reduced && t > .86 && t < .94;
    for (final side in [-1.0, 1.0]) {
      final c = Offset(s * (.5 + side * .16), s * .45);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(side * -.25);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * .19, height: s * .24), black);
      canvas.restore();
      final closed = blink || expression == 'sleepy' || expression == 'laugh' ||
          (expression == 'wink' && side > 0);
      if (closed) {
        canvas.drawArc(Rect.fromCenter(center: c, width: s * .1, height: s * .07),
          0, math.pi, false, eye..style = PaintingStyle.stroke..strokeWidth = s * .025);
        eye.style = PaintingStyle.fill;
      } else {
        canvas.drawCircle(c + Offset(math.sin(t * math.pi * 2) * s * .006, 0), s * .035, eye);
        canvas.drawCircle(c + Offset(s * .012, -s * .012), s * .012, black);
      }
      if (expression == 'angry') {
        canvas.drawLine(c + Offset(-s * .055, -s * .085 * side),
          c + Offset(s * .055, s * .02 * side),
          black..strokeWidth = s * .035..strokeCap = StrokeCap.round);
      }
      if (expression == 'sad' || expression == 'heartbreak') {
        final phase = (t + (side > 0 ? .4 : 0)) % 1;
        canvas.drawOval(Rect.fromCenter(center: c + Offset(side * s * .06, s * (.09 + phase * .15)),
          width: s * .045, height: s * .075),
          Paint()..color = const Color(0xFF72C9FF).withValues(alpha: 1 - phase));
      }
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(s * .5, s * .57), width: s * .08, height: s * .055), black);
    final mouth = Rect.fromCenter(center: Offset(s * .5, s * .65), width: s * .17, height: s * .12);
    if (expression == 'surprise' || expression == 'think') {
      canvas.drawOval(Rect.fromCenter(center: mouth.center, width: s * .075, height: s * .1), black);
    } else if (expression == 'laugh') {
      canvas.drawOval(mouth, black);
      canvas.drawOval(Rect.fromCenter(center: mouth.center + Offset(0, s * .035),
        width: s * .1, height: s * .04), Paint()..color = const Color(0xFFFF8AB1));
    } else {
      final sad = expression == 'sad' || expression == 'heartbreak' || expression == 'angry';
      canvas.drawArc(mouth, sad ? math.pi : 0, math.pi, false,
        black..style = PaintingStyle.stroke..strokeWidth = s * .02);
      black.style = PaintingStyle.fill;
    }
    if (const {'love', 'kiss', 'shy', 'hug', 'rose'}.contains(expression)) {
      for (final side in [-1.0, 1.0]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(s * (.5 + side * .23), s * .57),
          width: s * .11, height: s * .06),
          Paint()..color = const Color(0xFFFF87AC).withValues(alpha: .65));
      }
    }
    if (expression == 'cool') {
      for (final side in [-1.0, 1.0]) {
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(s * (.5 + side * .15), s * .43), width: s * .23, height: s * .12),
          Radius.circular(s * .025)), black);
      }
      canvas.drawLine(Offset(s * .39, s * .42), Offset(s * .61, s * .42), black..strokeWidth = s * .025);
    }
    if (expression == 'royal') {
      glyph(canvas, '👑', Offset(s * .5, s * .15), s * .36);
    } else {
      glyph(canvas, definition.glyph,
        Offset(s * .77, s * (.73 + (reduced ? 0 : math.sin(t * math.pi * 2) * .03))), s * .3);
    }
    canvas.restore();
  }
}

class _EnemyEmotePainter extends _EmotePainter {
  _EnemyEmotePainter({required super.definition, required super.timeline, required super.reduced});

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final center = size.center(Offset.zero);
    final scene = definition.enemyScene;
    final purple = scene == 'smoke';
    final color = purple ? const Color(0xFFB46BFF) : const Color(0xFFFF4C36);
    final halo = Rect.fromCircle(center: center, radius: s * .46);
    canvas.drawOval(halo, Paint()..shader = RadialGradient(colors: [
      color.withValues(alpha: .42), const Color(0xCC130C20), Colors.transparent,
    ]).createShader(halo));
    if (!reduced) {
      for (var i = 0; i < 8; i++) {
        final phase = (t + i / 8) % 1;
        final a = i * math.pi / 4 + t * math.pi;
        final point = center + Offset(math.cos(a), math.sin(a)) * s * (.22 + phase * .26);
        final p = Paint()..color = color.withValues(alpha: (1 - phase) * .85)
          ..strokeWidth = s * .025..strokeCap = StrokeCap.round;
        if (scene == 'smoke') {
          canvas.drawCircle(point, s * (.035 + phase * .055), p..color = color.withValues(alpha: (1 - phase) * .22));
        } else if (scene == 'lightning' || scene == 'clash' || scene == 'apocalypse') {
          final path = Path()..moveTo(point.dx, point.dy - s * .08)
            ..lineTo(point.dx + s * .04, point.dy)..lineTo(point.dx - s * .035, point.dy + s * .02)
            ..lineTo(point.dx + s * .045, point.dy + s * .12);
          canvas.drawPath(path, p..style = PaintingStyle.stroke);
        } else if (scene == 'fire') {
          final path = Path()..moveTo(point.dx, point.dy - s * .08)
            ..quadraticBezierTo(point.dx + s * .08, point.dy + s * .04, point.dx, point.dy + s * .07)
            ..quadraticBezierTo(point.dx - s * .06, point.dy, point.dx, point.dy - s * .08);
          canvas.drawPath(path, p);
        } else {
          canvas.drawLine(center + (point - center) * .75, point, p);
        }
      }
      if (scene == 'cracks' || scene == 'impact' || scene == 'apocalypse') {
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5;
          final start = center + Offset(math.cos(a), math.sin(a)) * s * .24;
          final end = center + Offset(math.cos(a + .13), math.sin(a + .13)) * s * .49;
          canvas.drawPath(Path()..moveTo(start.dx, start.dy)
            ..lineTo((start.dx + end.dx) / 2 + s * .035, (start.dy + end.dy) / 2)
            ..lineTo(end.dx, end.dy),
            Paint()..color = color.withValues(alpha: .5 + .2 * math.sin(t * math.pi * 4))
              ..style = PaintingStyle.stroke..strokeWidth = s * .02);
        }
      }
      if (scene == 'apocalypse') {
        for (var i = 0; i < 3; i++) {
          final phase = (t + i / 3) % 1;
          final point = Offset(size.width * (.2 + i * .3), size.height * phase);
          canvas.drawLine(point - Offset(s * .08, s * .13), point,
            Paint()..color = const Color(0xFFFFBE56).withValues(alpha: 1 - phase)
              ..strokeWidth = s * .035..strokeCap = StrokeCap.round);
        }
      }
    }
    final persona = definition.enemyPersona;
    if (persona == EnemyPersona.clash) {
      _rivalFace(canvas, center - Offset(s * .2, 0), s * .48, female: false);
      _rivalFace(canvas, center + Offset(s * .2, 0), s * .48, female: true);
      glyph(canvas, 'VS', center + Offset(0, s * .23), s * .2);
      glyph(canvas, definition.glyph, center - Offset(0, s * .27), s * .25);
    } else {
      _rivalFace(canvas, center, s * .84, female: persona == EnemyPersona.female);
      glyph(canvas, definition.glyph, center + Offset(s * .26, s * .25), s * .29);
    }
    if (definition.name.endsWith('Broken Crown')) {
      canvas.drawLine(center - Offset(s * .06, s * .2), center + Offset(s * .06, s * .2),
        Paint()..color = const Color(0xFF17101F)..strokeWidth = s * .035);
    }
    if (definition.name.endsWith('Rival Clash')) {
      glyph(canvas, 'VS', center + Offset(0, s * .28), s * .18);
    }
  }

  void _rivalFace(Canvas canvas, Offset center, double unit, {required bool female}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final dark = Paint()..color = const Color(0xFF130E20);
    final face = Paint()..color = female ? const Color(0xFF755B99) : const Color(0xFF657085);
    final accent = female ? const Color(0xFFE09DFF) : const Color(0xFFFF6655);
    // Long swept hair and lashes distinguish female rivals; angular jaw,
    // short spikes and heavy brows distinguish male rivals.
    if (female) {
      final hair = Path()..moveTo(-unit * .34, unit * .37)
        ..cubicTo(-unit * .51, -unit * .45, unit * .45, -unit * .52, unit * .37, unit * .39)
        ..lineTo(unit * .22, unit * .26)..lineTo(-unit * .22, unit * .26)..close();
      canvas.drawPath(hair, dark);
    }
    final head = female
        ? (Path()..moveTo(0, -unit * .31)
          ..cubicTo(-unit * .4, -unit * .34, -unit * .35, unit * .2, 0, unit * .35)
          ..cubicTo(unit * .35, unit * .2, unit * .4, -unit * .34, 0, -unit * .31))
        : (Path()..moveTo(-unit * .28, -unit * .29)..lineTo(unit * .28, -unit * .29)
          ..lineTo(unit * .29, unit * .12)..lineTo(unit * .15, unit * .32)
          ..lineTo(-unit * .15, unit * .32)..lineTo(-unit * .29, unit * .12)..close());
    canvas.drawPath(head, face);
    for (final side in [-1.0, 1.0]) {
      final horn = Path()..moveTo(side * unit * .14, -unit * .22)
        ..quadraticBezierTo(side * unit * .4, -unit * .25, side * unit * .37, -unit * .48)
        ..lineTo(side * unit * .27, -unit * .27)..close();
      canvas.drawPath(horn, Paint()..color = accent);
      final eye = Offset(side * unit * .13, -unit * .045);
      final blink = !reduced && t > .86 && t < .94;
      final eyePaint = Paint()..color = accent..strokeWidth = unit * .04..strokeCap = StrokeCap.round;
      if (blink) {
        canvas.drawLine(eye - Offset(unit * .05, 0), eye + Offset(unit * .05, 0), eyePaint);
      } else {
        canvas.drawOval(Rect.fromCenter(center: eye, width: unit * .14, height: unit * .055), eyePaint);
        canvas.drawCircle(eye, unit * .02, dark);
      }
      canvas.drawLine(eye + Offset(-unit * .07, -unit * .085 * side),
        eye + Offset(unit * .07, unit * .005 * side),
        dark..strokeWidth = unit * (female ? .025 : .04)..strokeCap = StrokeCap.round);
      if (female) {
        canvas.drawLine(eye + Offset(side * unit * .06, -unit * .02),
          eye + Offset(side * unit * .11, -unit * .07), dark..strokeWidth = unit * .02);
      }
    }
    if (female) {
      final fringe = Path()..moveTo(-unit * .29, -unit * .23)
        ..quadraticBezierTo(unit * .15, -unit * .43, unit * .27, -unit * .08)
        ..quadraticBezierTo(unit * .02, -unit * .3, -unit * .17, -unit * .04)..close();
      canvas.drawPath(fringe, dark);
    } else {
      final spikes = Path()..moveTo(-unit * .29, -unit * .19)
        ..lineTo(-unit * .24, -unit * .34)..lineTo(-unit * .08, -unit * .27)
        ..lineTo(0, -unit * .4)..lineTo(unit * .13, -unit * .27)
        ..lineTo(unit * .26, -unit * .35)..lineTo(unit * .3, -unit * .16)..close();
      canvas.drawPath(spikes, dark);
    }
    final grin = Path()..moveTo(-unit * .11, unit * .16)
      ..quadraticBezierTo(0, unit * .23, unit * .12, unit * .13);
    canvas.drawPath(grin, Paint()..color = female ? const Color(0xFFFF87D4) : Colors.white
      ..style = PaintingStyle.stroke..strokeWidth = unit * .023);
    canvas.restore();
  }

}
