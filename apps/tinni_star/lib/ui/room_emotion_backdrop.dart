import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const Set<String> emotionRoomThemeIds = <String>{
  'mood-happy',
  'mood-sad',
  'mood-boring',
  'mood-love',
  'mood-mountain-view',
  'mood-alone',
  'mood-with-her',
  'mood-with-him',
  'mood-love-scene',
  'mood-rainy-love',
};

bool isEmotionRoomTheme(String id) => emotionRoomThemeIds.contains(id);

class RoomEmotionBackdrop extends StatelessWidget {
  const RoomEmotionBackdrop({
    super.key,
    required this.themeId,
  });

  final String themeId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _EmotionThemePainter(themeId),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _EmotionThemePainter extends CustomPainter {
  const _EmotionThemePainter(this.id);

  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _palette(id);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * .2, 0),
          Offset(size.width * .8, size.height),
          palette,
        ),
    );

    _softGlow(canvas, size, palette.last);
    if (id == 'mood-sad' || id == 'mood-rainy-love') {
      _rain(canvas, size);
    }
    if (id == 'mood-mountain-view') {
      _mountains(canvas, size);
    } else if (id == 'mood-alone' || id == 'mood-with-him') {
      _skyline(canvas, size);
    } else if (id == 'mood-love-scene') {
      _stars(canvas, size);
      _heartLights(canvas, size);
    } else if (id == 'mood-happy' || id == 'mood-love' || id == 'mood-with-her') {
      _warmLights(canvas, size);
    }

    switch (id) {
      case 'mood-happy':
        _sofa(canvas, size);
        _couple(canvas, size, center: Offset(size.width * .52, size.height * .58), scale: 1.12);
        break;
      case 'mood-sad':
        _window(canvas, size);
        _person(canvas, Offset(size.width * .66, size.height * .61), size.width * .11, Colors.black.withValues(alpha: .72));
        break;
      case 'mood-boring':
        _desk(canvas, size);
        _person(canvas, Offset(size.width * .45, size.height * .58), size.width * .1, Colors.black.withValues(alpha: .7));
        break;
      case 'mood-love':
        _heart(canvas, Offset(size.width * .5, size.height * .3), size.width * .12, const Color(0x99FF4B76));
        _couple(canvas, size, center: Offset(size.width * .5, size.height * .6), scale: 1.05);
        break;
      case 'mood-mountain-view':
        _person(canvas, Offset(size.width * .5, size.height * .72), size.width * .095, Colors.black.withValues(alpha: .75));
        break;
      case 'mood-alone':
        _bench(canvas, size);
        _person(canvas, Offset(size.width * .49, size.height * .69), size.width * .09, Colors.black.withValues(alpha: .82));
        break;
      case 'mood-with-her':
        _campfire(canvas, size);
        _couple(canvas, size, center: Offset(size.width * .52, size.height * .64), scale: .95);
        break;
      case 'mood-with-him':
        _couple(canvas, size, center: Offset(size.width * .5, size.height * .66), scale: .92);
        break;
      case 'mood-love-scene':
        _moon(canvas, size);
        _couple(canvas, size, center: Offset(size.width * .5, size.height * .68), scale: .95);
        break;
      case 'mood-rainy-love':
        _umbrella(canvas, size);
        _couple(canvas, size, center: Offset(size.width * .5, size.height * .66), scale: .9);
        break;
    }

    canvas.drawRect(
      rect,
      Paint()..color = Colors.black.withValues(alpha: .13),
    );
  }

  List<Color> _palette(String value) {
    switch (value) {
      case 'mood-happy':
        return const [Color(0xFF4A1531), Color(0xFFB24A44), Color(0xFF24101C)];
      case 'mood-sad':
        return const [Color(0xFF071626), Color(0xFF173E5D), Color(0xFF05070D)];
      case 'mood-boring':
        return const [Color(0xFF22162D), Color(0xFF4B3764), Color(0xFF111018)];
      case 'mood-love':
        return const [Color(0xFF350813), Color(0xFFAA203E), Color(0xFF17050A)];
      case 'mood-mountain-view':
        return const [Color(0xFF4D6D8A), Color(0xFFE29B62), Color(0xFF192633)];
      case 'mood-alone':
        return const [Color(0xFF07111E), Color(0xFF18354D), Color(0xFF03060A)];
      case 'mood-with-her':
        return const [Color(0xFF4B1C17), Color(0xFFC66A3B), Color(0xFF12090B)];
      case 'mood-with-him':
        return const [Color(0xFF07172A), Color(0xFF173E62), Color(0xFF06060A)];
      case 'mood-love-scene':
        return const [Color(0xFF120831), Color(0xFF452060), Color(0xFF090514)];
      case 'mood-rainy-love':
        return const [Color(0xFF16212E), Color(0xFF65403B), Color(0xFF080A0D)];
      default:
        return const [Color(0xFF03070B), Color(0xFF101722)];
    }
  }

  void _softGlow(Canvas canvas, Size size, Color color) {
    canvas.drawCircle(
      Offset(size.width * .55, size.height * .24),
      size.width * .54,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * .55, size.height * .24),
          size.width * .54,
          [color.withValues(alpha: .42), Colors.transparent],
        ),
    );
  }

  void _warmLights(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFFFD78B).withValues(alpha: .62);
    for (var i = 0; i < 18; i++) {
      final x = size.width * (.07 + (i % 9) * .11);
      final y = size.height * (.12 + (i ~/ 9) * .08 + ((i % 3) * .012));
      canvas.drawCircle(Offset(x, y), 2.3 + (i % 2), p);
    }
  }

  void _stars(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .7);
    for (var i = 0; i < 42; i++) {
      final x = ((i * 73) % 997) / 997 * size.width;
      final y = (((i * 47) + 31) % 509) / 509 * size.height * .48;
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.6 : .8, p);
    }
  }

  void _rain(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFB9D9F4).withValues(alpha: .35)
      ..strokeWidth = 1;
    for (var i = 0; i < 55; i++) {
      final x = ((i * 41) % 101) / 101 * size.width;
      final y = ((i * 67) % 103) / 103 * size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + 18), p);
    }
  }

  void _mountains(Canvas canvas, Size size) {
    final back = Path()
      ..moveTo(0, size.height * .58)
      ..lineTo(size.width * .22, size.height * .36)
      ..lineTo(size.width * .39, size.height * .54)
      ..lineTo(size.width * .61, size.height * .27)
      ..lineTo(size.width * .84, size.height * .52)
      ..lineTo(size.width, size.height * .39)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFF263949).withValues(alpha: .86));
    final front = Path()
      ..moveTo(0, size.height * .69)
      ..lineTo(size.width * .28, size.height * .49)
      ..lineTo(size.width * .5, size.height * .65)
      ..lineTo(size.width * .77, size.height * .43)
      ..lineTo(size.width, size.height * .65)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF101922).withValues(alpha: .9));
  }

  void _skyline(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF07101A).withValues(alpha: .92);
    final base = size.height * .72;
    for (var i = 0; i < 13; i++) {
      final w = size.width * (.045 + (i % 3) * .015);
      final h = size.height * (.08 + (i % 5) * .025);
      final x = size.width * (.02 + i * .078);
      canvas.drawRect(Rect.fromLTWH(x, base - h, w, h), p);
    }
    final light = Paint()..color = const Color(0xFFFFD477).withValues(alpha: .5);
    for (var i = 0; i < 20; i++) {
      final x = size.width * (.05 + (i % 10) * .095);
      final y = base - size.height * (.025 + (i ~/ 10) * .04);
      canvas.drawCircle(Offset(x, y), 1.4, light);
    }
  }

  void _window(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(size.width * .08, size.height * .12, size.width * .84, size.height * .52);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(18)),
      Paint()..color = const Color(0x3329A7E8),
    );
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .17)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(size.width * .5, r.top), Offset(size.width * .5, r.bottom), p);
  }

  void _desk(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF0D0C13).withValues(alpha: .75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .17, size.height * .67, size.width * .66, size.height * .055),
        const Radius.circular(8),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .52, size.height * .55, size.width * .25, size.height * .13),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF25213A),
    );
  }

  void _sofa(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .13, size.height * .62, size.width * .74, size.height * .18),
        const Radius.circular(28),
      ),
      Paint()..color = const Color(0xFF3A1C29).withValues(alpha: .78),
    );
  }

  void _bench(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF0C0D10).withValues(alpha: .88);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .23, size.height * .73, size.width * .54, size.height * .035),
        const Radius.circular(6),
      ),
      p,
    );
    canvas.drawRect(Rect.fromLTWH(size.width * .28, size.height * .76, 6, size.height * .1), p);
    canvas.drawRect(Rect.fromLTWH(size.width * .69, size.height * .76, 6, size.height * .1), p);
  }

  void _campfire(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .76);
    canvas.drawCircle(
      center,
      size.width * .12,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          size.width * .12,
          [const Color(0xFFFFB64A).withValues(alpha: .72), Colors.transparent],
        ),
    );
    final flame = Path()
      ..moveTo(center.dx, center.dy - size.width * .07)
      ..quadraticBezierTo(center.dx + size.width * .06, center.dy, center.dx, center.dy + size.width * .04)
      ..quadraticBezierTo(center.dx - size.width * .05, center.dy, center.dx, center.dy - size.width * .07)
      ..close();
    canvas.drawPath(flame, Paint()..color = const Color(0xFFFF8A2A));
  }

  void _moon(Canvas canvas, Size size) {
    final c = Offset(size.width * .76, size.height * .2);
    canvas.drawCircle(c, size.width * .085, Paint()..color = const Color(0xFFFFF1C7).withValues(alpha: .9));
    canvas.drawCircle(
      Offset(c.dx - size.width * .018, c.dy - size.width * .012),
      size.width * .075,
      Paint()..color = const Color(0xFF32194F).withValues(alpha: .32),
    );
  }

  void _umbrella(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .49);
    final path = Path()
      ..moveTo(center.dx - size.width * .24, center.dy)
      ..quadraticBezierTo(center.dx, center.dy - size.width * .23, center.dx + size.width * .24, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF11161D).withValues(alpha: .92));
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy + size.height * .19),
      Paint()
        ..color = const Color(0xFF11161D)
        ..strokeWidth = 4,
    );
  }

  void _heartLights(Canvas canvas, Size size) {
    for (var i = 0; i < 9; i++) {
      final a = math.pi * (1 + i / 8);
      final x = size.width * .5 + math.cos(a) * size.width * .34;
      final y = size.height * .34 + math.sin(a) * size.height * .16;
      _heart(canvas, Offset(x, y), size.width * .025, const Color(0xCCFF3E68));
    }
  }

  void _couple(Canvas canvas, Size size, {required Offset center, double scale = 1}) {
    final unit = size.width * .09 * scale;
    _person(canvas, Offset(center.dx - unit * .48, center.dy), unit, Colors.black.withValues(alpha: .82));
    _person(canvas, Offset(center.dx + unit * .48, center.dy + unit * .04), unit * .94, Colors.black.withValues(alpha: .78));
  }

  void _person(Canvas canvas, Offset center, double unit, Color color) {
    final p = Paint()..color = color;
    canvas.drawCircle(Offset(center.dx, center.dy - unit * 1.32), unit * .42, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy - unit * .48), width: unit * .86, height: unit * 1.28),
        Radius.circular(unit * .34),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - unit * .35, center.dy + unit * .12, unit * .28, unit * 1.1),
        Radius.circular(unit * .14),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx + unit * .07, center.dy + unit * .12, unit * .28, unit * 1.1),
        Radius.circular(unit * .14),
      ),
      p,
    );
  }

  void _heart(Canvas canvas, Offset center, double size, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * .75)
      ..cubicTo(center.dx - size * 1.1, center.dy, center.dx - size * .7, center.dy - size * .8, center.dx, center.dy - size * .22)
      ..cubicTo(center.dx + size * .7, center.dy - size * .8, center.dx + size * 1.1, center.dy, center.dx, center.dy + size * .75)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _EmotionThemePainter oldDelegate) =>
      oldDelegate.id != id;
}
