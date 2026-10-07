import 'dart:math' as math;

import 'package:flutter/material.dart';

const reactionFaceEmojis = <String>{
  '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '🥰',
  '😎', '🤩', '🥳', '😇', '🙂', '🙃', '😉', '😋',
  '😜', '🤪', '🤗', '🤭', '🫣', '🤔', '🫡', '😴',
  '😭', '🥺', '😢', '😡', '🤬', '😱', '😳', '🫠',
};

class EmojiReactionFace extends StatelessWidget {
  const EmojiReactionFace({super.key, required this.emoji, required this.timeline, required this.size});
  final String emoji;
  final Animation<double> timeline;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: CustomPaint(
      key: ValueKey('emoji-face-$emoji'),
      painter: _ReactionFacePainter(emoji: emoji, timeline: timeline,
        reduced: MediaQuery.maybeOf(context)?.disableAnimations ?? false),
    ),
  );
}

class _ReactionFacePainter extends CustomPainter {
  _ReactionFacePainter({required this.emoji, required this.timeline, required this.reduced})
      : super(repaint: timeline);
  final String emoji;
  final Animation<double> timeline;
  final bool reduced;

  void symbol(Canvas canvas, String text, Offset center, double size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: const Color(0xFFEC4679))),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(size.width, size.height);
    final t = reduced ? 0.0 : timeline.value;
    final wave = reduced ? 0.0 : math.sin(t * math.pi * 2);
    final laughing = const {'😀', '😁', '😂', '🤣'}.contains(emoji);
    final sad = const {'😭', '🥺', '😢'}.contains(emoji);
    final angry = const {'😡', '🤬'}.contains(emoji);
    final surprise = const {'😱', '😳', '🫣'}.contains(emoji);
    final sleep = emoji == '😴';
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    if (emoji == '🙃') canvas.rotate(math.pi);
    final head = Rect.fromCircle(center: Offset.zero, radius: unit * .37);
    canvas.drawOval(head, Paint()..shader = RadialGradient(
      center: const Alignment(-.3, -.4),
      colors: angry
          ? const [Color(0xFFFFBE4B), Color(0xFFF14E2E)]
          : const [Color(0xFFFFEF90), Color(0xFFFFBD3C)],
    ).createShader(head));
    final dark = Paint()..color = const Color(0xFF49322A);
    final stroke = Paint()..color = dark.color..style = PaintingStyle.stroke
      ..strokeWidth = unit * .028..strokeCap = StrokeCap.round;
    final blink = !reduced && t > .87 && t < .95;
    for (final side in [-1.0, 1.0]) {
      final eye = Offset(side * unit * .14, -unit * .095);
      final closed = blink || sleep || emoji == '😂' || emoji == '🤣' ||
          (const {'😉', '😘', '😜'}.contains(emoji) && side > 0);
      if (emoji == '😍') {
        symbol(canvas, '♥', eye, unit * (.2 + wave * .025));
      } else if (emoji == '🤩') {
        symbol(canvas, '⭐', eye, unit * (.19 + wave * .02));
      } else if (closed) {
        canvas.drawArc(Rect.fromCenter(center: eye, width: unit * .13, height: unit * .075),
          sleep ? math.pi : 0, math.pi, false, stroke);
      } else {
        final height = sad ? unit * .12 : unit * (.1 + wave * (surprise ? .016 : .008));
        canvas.drawOval(Rect.fromCenter(center: eye, width: unit * (sad ? .1 : .065), height: height), dark);
        if (sad || surprise) {
          canvas.drawCircle(eye + Offset(-unit * .012, -unit * .025), unit * .018, Paint()..color = Colors.white);
        }
      }
      if (sad || angry || emoji == '🤔') {
        final tilt = sad ? -side : side;
        canvas.drawLine(eye + Offset(-unit * .065, -unit * .1 * tilt),
          eye + Offset(unit * .065, unit * .015 * tilt), stroke);
      }
      if (const {'😊', '🥰', '😘', '😳'}.contains(emoji)) {
        canvas.drawOval(Rect.fromCenter(center: eye + Offset(side * unit * .055, unit * .14),
          width: unit * .11, height: unit * .06),
          Paint()..color = const Color(0xFFEF775A).withValues(alpha: .55 + wave * .1));
      }
      if (const {'😭', '😢', '😂', '🤣'}.contains(emoji)) {
        final phase = reduced ? .35 : (t + (side > 0 ? .4 : 0)) % 1;
        canvas.drawOval(Rect.fromCenter(
          center: eye + Offset(side * unit * .08, unit * (.07 + phase * .19)),
          width: unit * .05, height: unit * .09),
          Paint()..color = const Color(0xFF55BCF6).withValues(alpha: 1 - phase * .7));
      }
    }
    final mouthCenter = Offset(0, unit * .16);
    final mouth = Rect.fromCenter(center: mouthCenter,
      width: unit * .28, height: unit * (.14 + (laughing ? wave.abs() * .07 : 0)));
    if (laughing || emoji == '🥳') {
      canvas.drawArc(mouth, 0, math.pi, true, dark);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: mouthCenter + Offset(0, unit * .013),
          width: unit * .2, height: unit * .035), Radius.circular(unit * .01)),
        Paint()..color = Colors.white);
    } else if (sad) {
      canvas.drawArc(mouth, math.pi, math.pi, false, stroke);
    } else if (surprise) {
      canvas.drawOval(Rect.fromCenter(center: mouthCenter,
        width: unit * .085, height: unit * (.11 + wave.abs() * .025)), dark);
    } else if (emoji == '😘') {
      final kiss = Path()..moveTo(-unit * .045, unit * .12)
        ..lineTo(unit * .025, unit * .16)..lineTo(-unit * .04, unit * .19);
      canvas.drawPath(kiss, stroke);
      symbol(canvas, '💋', Offset(unit * .27, unit * (.13 - wave * .05)), unit * .22);
    } else if (sleep) {
      canvas.drawOval(Rect.fromCenter(center: mouthCenter, width: unit * .06, height: unit * .08), dark);
      symbol(canvas, '💤', Offset(unit * .25, -unit * (.22 + wave * .03)), unit * .23);
    } else if (angry) {
      canvas.drawLine(mouthCenter - Offset(unit * .1, 0), mouthCenter + Offset(unit * .1, 0), stroke);
      if (emoji == '🤬') symbol(canvas, '💢', Offset(unit * .25, -unit * .27), unit * .2);
    } else {
      canvas.drawArc(mouth, 0, math.pi, false, stroke);
      if (const {'😋', '😜', '🤪'}.contains(emoji)) {
        canvas.drawOval(Rect.fromCenter(center: mouthCenter + Offset(unit * .05, unit * (.065 + wave * .012)),
          width: unit * .09, height: unit * .1), Paint()..color = const Color(0xFFF27992));
      }
    }
    if (emoji == '😎') {
      for (final side in [-1.0, 1.0]) {
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(side * unit * .145, -unit * .09),
            width: unit * .22, height: unit * .12), Radius.circular(unit * .025)), dark);
      }
      canvas.drawLine(Offset(-unit * .05, -unit * .1), Offset(unit * .05, -unit * .1), stroke);
    }
    if (emoji == '😇') {
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -unit * (.36 + wave * .02)),
        width: unit * .45, height: unit * .08),
        Paint()..color = const Color(0xFF7EDCFF)..style = PaintingStyle.stroke..strokeWidth = unit * .028);
    }
    if (emoji == '🥳') symbol(canvas, '🎉', Offset(unit * .23, -unit * .28), unit * .26);
    if (emoji == '🥰') {
      symbol(canvas, '💕', Offset(-unit * .25, -unit * (.28 + wave * .025)), unit * .25);
    }
    if (const {'🤗', '🤭', '🫣', '🤔', '🫡', '😱'}.contains(emoji)) {
      final hand = switch (emoji) {
        '🤗' => '👐', '🤭' => '🤚', '🫣' => '👐', '🤔' => '☝️', '🫡' => '✋', _ => '🙌',
      };
      final point = switch (emoji) {
        '🫣' => Offset(0, -unit * (.06 + wave.abs() * .07)),
        '🫡' => Offset(unit * .26, -unit * .2),
        '🤭' => Offset(0, unit * (.17 + wave * .012)),
        '🤔' => Offset(unit * .13, unit * .21),
        _ => Offset(0, unit * (.28 + wave * .018)),
      };
      symbol(canvas, hand, point, unit * (emoji == '🫣' ? .42 : .29));
    }
    if (emoji == '🫠') {
      for (var i = 0; i < 4; i++) {
        canvas.drawOval(Rect.fromCenter(center: Offset(unit * (-.2 + i * .13),
          unit * (.3 + (1 + wave) * .015 * (i % 2 + 1))),
          width: unit * .13, height: unit * .09), Paint()..color = const Color(0xFFFFBD3C));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReactionFacePainter oldDelegate) =>
      oldDelegate.emoji != emoji || oldDelegate.timeline != timeline || oldDelegate.reduced != reduced;
}
