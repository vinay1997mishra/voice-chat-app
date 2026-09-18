import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'gift_catalog_v08.dart';

class GiftEffectV08 {
  const GiftEffectV08._();

  static Future<void> show(
    BuildContext context,
    GiftV08 gift, {
    String sender = 'You',
    String receiver = 'Receiver',
  }) async {
    if (gift.animationTier == GiftAnimationTierV08.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${gift.emoji} ${gift.name} sent to $receiver')),
      );
      return;
    }

    if (!gift.isFullscreen3d) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _GiftStageV08(
          gift: gift,
          sender: sender,
          receiver: receiver,
          compact: true,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _GiftStageV08(
          gift: gift,
          sender: sender,
          receiver: receiver,
          compact: false,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }
}

class _GiftStageV08 extends StatefulWidget {
  const _GiftStageV08({
    required this.gift,
    required this.sender,
    required this.receiver,
    required this.compact,
  });

  final GiftV08 gift;
  final String sender;
  final String receiver;
  final bool compact;

  @override
  State<_GiftStageV08> createState() => _GiftStageV08State();
}

class _GiftStageV08State extends State<_GiftStageV08>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  Duration get duration {
    switch (widget.gift.animationTier) {
      case GiftAnimationTierV08.none:
        return const Duration(milliseconds: 700);
      case GiftAnimationTierV08.light3d:
        return const Duration(milliseconds: 1500);
      case GiftAnimationTierV08.fullscreen3d:
        return const Duration(milliseconds: 2200);
      case GiftAnimationTierV08.premium3d:
        return const Duration(milliseconds: 2800);
      case GiftAnimationTierV08.cinematic3d:
        return const Duration(milliseconds: 3600);
      case GiftAnimationTierV08.ultraRide3d:
        return const Duration(milliseconds: 4800);
    }
  }

  double get intensity {
    final coins = widget.gift.coins.toDouble().clamp(10000, 30000000);
    final minLog = math.log(10000);
    final maxLog = math.log(30000000);
    return ((math.log(coins) - minLog) / (maxLog - minLog)).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          Navigator.of(context).maybePop();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gift = widget.gift;
    return Material(
      color: widget.compact ? Colors.transparent : Colors.black.withOpacity(.86),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(controller.value);
            final enter = Curves.elasticOut.transform(
              (controller.value / .55).clamp(0.0, 1.0),
            );
            final pulse = 1 + math.sin(t * math.pi * 5) * (.025 + intensity * .035);
            final rotateY = math.sin(t * math.pi * 2) * (.08 + intensity * .12);
            final rotateX = math.sin(t * math.pi) * (.02 + intensity * .06);
            final scene = Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0014)
                ..rotateY(rotateY)
                ..rotateX(rotateX)
                ..scale((.78 + enter * .22) * pulse),
              child: gift.category == GiftCategoryV08.ultraRide
                  ? _UltraRideGiftV08(gift: gift, progress: t)
                  : _StandardGiftVisualV08(gift: gift, intensity: intensity, progress: t),
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                if (!widget.compact)
                  _GiftBackgroundV08(
                    theme: gift.theme,
                    intensity: intensity,
                    progress: t,
                  ),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.compact ? 330 : 560,
                      maxHeight: widget.compact ? 430 : 700,
                    ),
                    child: scene,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: _GiftCaptionV08(
                      gift: gift,
                      sender: widget.sender,
                      receiver: widget.receiver,
                    ),
                  ),
                ),
                if (!widget.compact)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GiftCaptionV08 extends StatelessWidget {
  const _GiftCaptionV08({
    required this.gift,
    required this.sender,
    required this.receiver,
  });

  final GiftV08 gift;
  final String sender;
  final String receiver;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.52),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              gift.name,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$sender → $receiver  •  ${formatGiftCoinsV08(gift.coins)} Coins',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
}

class _StandardGiftVisualV08 extends StatelessWidget {
  const _StandardGiftVisualV08({
    required this.gift,
    required this.intensity,
    required this.progress,
  });

  final GiftV08 gift;
  final double intensity;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = 110 + intensity * 130;
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < 10; i++)
          Transform.rotate(
            angle: progress * math.pi * 2 + i * math.pi / 5,
            child: Transform.translate(
              offset: Offset(0, -(70 + intensity * 75)),
              child: Opacity(
                opacity: (.22 + intensity * .35).clamp(0, 1),
                child: Icon(
                  i.isEven ? Icons.auto_awesome : Icons.circle,
                  size: 8 + intensity * 9,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        Container(
          width: size + 80,
          height: size + 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                blurRadius: 45 + intensity * 70,
                spreadRadius: 4 + intensity * 14,
                color: Colors.deepPurpleAccent.withOpacity(.28 + intensity * .25),
              ),
            ],
          ),
        ),
        Text(gift.emoji, style: TextStyle(fontSize: size)),
      ],
    );
  }
}

class _UltraRideGiftV08 extends StatelessWidget {
  const _UltraRideGiftV08({required this.gift, required this.progress});
  final GiftV08 gift;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final isEagle = gift.name == 'Eagles King';
    final isPhoenix = gift.name == 'Phoenix King';
    final drift = math.sin(progress * math.pi * 2) * 18;

    return Transform.translate(
      offset: Offset(drift, -18 * math.sin(progress * math.pi)),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 390,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(80),
              boxShadow: [
                BoxShadow(
                  color: isEagle
                      ? Colors.blueGrey.withOpacity(.5)
                      : isPhoenix
                          ? Colors.deepOrange.withOpacity(.55)
                          : Colors.deepPurpleAccent.withOpacity(.55),
                  blurRadius: 90,
                  spreadRadius: 18,
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(410, 300),
            painter: _RideCreaturePainterV08(
              name: gift.name,
              progress: progress,
            ),
          ),
          Positioned(
            top: 73,
            child: Column(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 56,
                  color: Colors.white.withOpacity(.96),
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 8),
                  ],
                ),
                const SizedBox(height: 86),
                Text(
                  gift.name,
                  style: const TextStyle(
                    fontSize: 31,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RideCreaturePainterV08 extends CustomPainter {
  const _RideCreaturePainterV08({required this.name, required this.progress});

  final String name;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .56);
    final isEagle = name == 'Eagles King';
    final isPhoenix = name == 'Phoenix King';

    final main = Paint()
      ..color = isEagle
          ? const Color(0xFF080A0F)
          : isPhoenix
              ? const Color(0xFFFF5A1F)
              : const Color(0xFF512DA8)
      ..style = PaintingStyle.fill;

    final glow = Paint()
      ..color = isEagle
          ? const Color(0xFF607D8B).withOpacity(.35)
          : isPhoenix
              ? const Color(0xFFFFD54F).withOpacity(.45)
              : const Color(0xFFE040FB).withOpacity(.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);

    final flap = 34 * math.sin(progress * math.pi * 6);

    final leftWing = Path()
      ..moveTo(center.dx - 30, center.dy)
      ..quadraticBezierTo(
        center.dx - 125,
        center.dy - 105 - flap,
        center.dx - 195,
        center.dy - 8,
      )
      ..quadraticBezierTo(
        center.dx - 110,
        center.dy - 30,
        center.dx - 16,
        center.dy + 34,
      )
      ..close();

    final rightWing = Path()
      ..moveTo(center.dx + 30, center.dy)
      ..quadraticBezierTo(
        center.dx + 125,
        center.dy - 105 - flap,
        center.dx + 195,
        center.dy - 8,
      )
      ..quadraticBezierTo(
        center.dx + 110,
        center.dy - 30,
        center.dx + 16,
        center.dy + 34,
      )
      ..close();

    canvas.drawPath(leftWing, glow);
    canvas.drawPath(rightWing, glow);
    canvas.drawPath(leftWing, main);
    canvas.drawPath(rightWing, main);

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: name == 'Dragon King' ? 190 : 125,
        height: 74,
      ),
      main,
    );

    if (name == 'Dragon King') {
      final tail = Path()
        ..moveTo(center.dx + 70, center.dy + 10)
        ..quadraticBezierTo(
          center.dx + 170,
          center.dy + 35,
          center.dx + 185,
          center.dy + 105,
        )
        ..quadraticBezierTo(
          center.dx + 140,
          center.dy + 65,
          center.dx + 60,
          center.dy + 38,
        )
        ..close();
      canvas.drawPath(tail, main);
    }

    final head = Offset(center.dx, center.dy - 48);
    canvas.drawCircle(head, isEagle ? 34 : 30, main);

    if (isEagle) {
      final beak = Path()
        ..moveTo(head.dx + 22, head.dy)
        ..lineTo(head.dx + 55, head.dy + 10)
        ..lineTo(head.dx + 20, head.dy + 18)
        ..close();
      canvas.drawPath(beak, Paint()..color = const Color(0xFFFFC107));
    }

    if (isPhoenix) {
      for (var i = 0; i < 5; i++) {
        final x = center.dx - 55 + i * 27;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, center.dy + 70 + 10 * math.sin(progress * math.pi * 4 + i)),
            width: 23,
            height: 110,
          ),
          Paint()..color = const Color(0xFFFFB300).withOpacity(.7),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RideCreaturePainterV08 oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.name != name;
}

class _GiftBackgroundV08 extends StatelessWidget {
  const _GiftBackgroundV08({
    required this.theme,
    required this.intensity,
    required this.progress,
  });

  final String theme;
  final double intensity;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final dark = theme.contains('black') || theme.contains('storm');
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 1.15,
          colors: dark
              ? const [Color(0xFF263238), Color(0xFF050608)]
              : const [Color(0xFF4A148C), Color(0xFF120316)],
        ),
      ),
      child: Stack(
        children: [
          for (var i = 0; i < 22; i++)
            Positioned(
              left: ((i * 47 + progress * 170) % 390),
              top: ((i * 83 + progress * 260) % 760),
              child: Opacity(
                opacity: (.12 + intensity * .45).clamp(0, 1),
                child: Icon(
                  i % 3 == 0 ? Icons.auto_awesome : Icons.circle,
                  size: 4 + (i % 4) * 2 + intensity * 4,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
