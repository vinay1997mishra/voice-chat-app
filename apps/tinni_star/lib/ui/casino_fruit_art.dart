import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Resolution-independent fruit artwork: no emoji/font or network dependency.
class CasinoFruitArt extends StatelessWidget {
  const CasinoFruitArt({super.key, required this.fruitKey, this.size = 48});
  final String fruitKey;
  final double size;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FruitPainter(fruitKey)),
    ),
  );
}

class _FruitPainter extends CustomPainter {
  const _FruitPainter(this.fruitKey);
  final String fruitKey;

  Paint fill(Color color) => Paint()..color = color;
  Paint gradient(Rect bounds, Color light, Color dark) => Paint()
    ..shader = RadialGradient(
      center: const Alignment(-.45, -.55),
      radius: 1.15,
      colors: [light, dark],
    ).createShader(bounds);

  void leaf(Canvas canvas, Offset origin, {double angle = 0}) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final shape = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(4, -21, 28, -15)
      ..quadraticBezierTo(20, 3, 0, 0);
    canvas.drawPath(shape, gradient(const Rect.fromLTWH(0, -20, 30, 24),
      const Color(0xFF86DF51), const Color(0xFF178442)));
    canvas.drawLine(const Offset(2, -2), const Offset(22, -13),
      Paint()..color = const Color(0xAAE2FFC3)..strokeWidth = 1.2);
    canvas.restore();
  }

  void stem(Canvas canvas, Path path) => canvas.drawPath(path,
    Paint()..color = const Color(0xFF437331)..style = PaintingStyle.stroke
      ..strokeWidth = 4..strokeCap = StrokeCap.round);

  void shine(Canvas canvas, Offset at, double radius) {
    canvas.drawOval(Rect.fromCenter(center: at, width: radius, height: radius * .45),
      fill(const Color(0x99FFFFFF)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawOval(const Rect.fromLTWH(20, 84, 63, 9), fill(const Color(0x170F0525)));
    switch (fruitKey) {
      case 'lemon':
        canvas.save();
        canvas.translate(50, 55);
        canvas.rotate(-.38);
        final shape = Path()
          ..moveTo(-43, 0)..quadraticBezierTo(-34, -3, -30, -17)
          ..cubicTo(-16, -35, 25, -29, 34, -7)
          ..quadraticBezierTo(39, -2, 43, 0)
          ..quadraticBezierTo(35, 4, 30, 16)
          ..cubicTo(13, 33, -26, 30, -34, 8)..close();
        canvas.drawPath(shape, gradient(const Rect.fromLTWH(-43, -30, 86, 62),
          const Color(0xFFFFFF80), const Color(0xFFF4B414)));
        shine(canvas, const Offset(-12, -12), 25);
        canvas.restore();
        leaf(canvas, const Offset(65, 32), angle: -.35);
      case 'cherry':
        stem(canvas, Path()..moveTo(33, 58)..quadraticBezierTo(43, 34, 54, 16)
          ..moveTo(65, 62)..quadraticBezierTo(62, 33, 54, 16));
        leaf(canvas, const Offset(54, 18), angle: .45);
        for (final center in [const Offset(32, 66), const Offset(66, 70)]) {
          final bounds = Rect.fromCircle(center: center, radius: 21);
          canvas.drawOval(bounds, gradient(bounds, const Color(0xFFFF6372), const Color(0xFFAA123E)));
          shine(canvas, center + const Offset(-7, -8), 13);
        }
      case 'kiwi':
        final outer = const Rect.fromLTWH(12, 19, 76, 69);
        canvas.drawOval(outer, gradient(outer, const Color(0xFFBD945C), const Color(0xFF74513E)));
        final flesh = const Rect.fromLTWH(18, 24, 63, 58);
        canvas.drawOval(flesh, gradient(flesh, const Color(0xFFD8FF7B), const Color(0xFF60B824)));
        canvas.drawOval(const Rect.fromLTWH(39, 42, 22, 23), fill(const Color(0xFFFFF5C8)));
        for (var i = 0; i < 12; i++) {
          final angle = i * math.pi / 6;
          canvas.drawOval(Rect.fromCenter(
            center: Offset(50 + math.cos(angle) * 23, 54 + math.sin(angle) * 19),
            width: 3.5, height: 5), fill(const Color(0xFF26351B)));
        }
        shine(canvas, const Offset(32, 36), 15);
      case 'strawberry':
        final shape = Path()..moveTo(18, 38)
          ..cubicTo(20, 18, 79, 19, 82, 39)
          ..cubicTo(80, 59, 62, 84, 50, 91)
          ..cubicTo(37, 84, 20, 60, 18, 38)..close();
        canvas.drawPath(shape, gradient(const Rect.fromLTWH(18, 22, 64, 70),
          const Color(0xFFFF7188), const Color(0xFFD32145)));
        for (final point in [const Offset(32, 42), const Offset(49, 40),
          const Offset(66, 43), const Offset(40, 57), const Offset(59, 59),
          const Offset(49, 74)]) {
          canvas.drawOval(Rect.fromCenter(center: point, width: 3.3, height: 5),
            fill(const Color(0xFFFFE9A0)));
        }
        for (var i = 0; i < 4; i++) {
          leaf(canvas, const Offset(48, 31), angle: -2.1 + i * .8);
        }
        shine(canvas, const Offset(30, 42), 12);
      case 'watermelon':
        Path slice(double left, double right, double bottom) => Path()
          ..moveTo(left, 35)..lineTo(right, 35)
          ..quadraticBezierTo(right - 2, bottom, 50, bottom)
          ..quadraticBezierTo(left + 2, bottom, left, 35)..close();
        canvas.drawPath(slice(8, 92, 90), fill(const Color(0xFF269B52)));
        canvas.drawPath(slice(13, 87, 83), fill(const Color(0xFFDDF3A0)));
        canvas.drawPath(slice(18, 82, 77), gradient(const Rect.fromLTWH(18, 35, 64, 42),
          const Color(0xFFFF7184), const Color(0xFFF02854)));
        for (final point in [const Offset(30, 45), const Offset(50, 44),
          const Offset(69, 45), const Offset(39, 59), const Offset(60, 59),
          const Offset(50, 70)]) {
          canvas.drawOval(Rect.fromCenter(center: point, width: 3, height: 5),
            fill(const Color(0xFF45142D)));
        }
      case 'banana':
        final shape = Path()..moveTo(21, 19)
          ..cubicTo(13, 47, 39, 83, 82, 58)
          ..lineTo(88, 64)
          ..cubicTo(39, 110, 4, 75, 10, 30)..close();
        canvas.drawPath(shape, gradient(const Rect.fromLTWH(8, 20, 82, 71),
          const Color(0xFFFFF698), const Color(0xFFF3BB25)));
        canvas.drawPath(Path()..moveTo(19, 38)..cubicTo(22, 68, 42, 84, 75, 68),
          Paint()..color = const Color(0xFFDC9E20)..style = PaintingStyle.stroke
            ..strokeWidth = 2.2..strokeCap = StrokeCap.round);
        canvas.drawLine(const Offset(14, 23), const Offset(22, 16),
          Paint()..color = const Color(0xFF675230)..strokeWidth = 7);
        shine(canvas, const Offset(31, 67), 15);
      case 'raspberry':
        for (var row = 0; row < 4; row++) {
          final count = row == 3 ? 2 : row + 2;
          for (var i = 0; i < count; i++) {
            final center = Offset(50 + (i - (count - 1) / 2) * 17, 38 + row * 14);
            final bounds = Rect.fromCircle(center: center, radius: 11);
            canvas.drawOval(bounds, gradient(bounds,
              const Color(0xFFFF799E), const Color(0xFFBE1B54)));
            shine(canvas, center + const Offset(-3, -4), 5);
          }
        }
        leaf(canvas, const Offset(46, 27), angle: -.4);
        leaf(canvas, const Offset(49, 28), angle: -2.3);
      case 'plum':
        stem(canvas, Path()..moveTo(50, 30)..quadraticBezierTo(48, 20, 57, 12));
        leaf(canvas, const Offset(52, 24), angle: .4);
        final bounds = const Rect.fromLTWH(19, 28, 65, 60);
        canvas.drawOval(bounds, gradient(bounds,
          const Color(0xFFC592F5), const Color(0xFF642895)));
        canvas.drawPath(Path()..moveTo(53, 31)..quadraticBezierTo(43, 56, 54, 85),
          Paint()..color = const Color(0x66551483)..style = PaintingStyle.stroke..strokeWidth = 2);
        shine(canvas, const Offset(35, 46), 17);
      default:
        canvas.drawCircle(const Offset(50, 50), 30, fill(const Color(0xFFFFCF65)));
    }
  }

  @override
  bool shouldRepaint(covariant _FruitPainter oldDelegate) => oldDelegate.fruitKey != fruitKey;
}
