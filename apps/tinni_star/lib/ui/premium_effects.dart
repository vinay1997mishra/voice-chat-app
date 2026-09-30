import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class PremiumEffectStyle {
  const PremiumEffectStyle({
    required this.id,
    required this.title,
    required this.icon,
    required this.colors,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<Color> colors;

  static const List<String> frameIds = <String>[
    'frame-royal-gold',
    'frame-pink-heart',
    'frame-crystal-star',
    'frame-crown-queen',
    'frame-rose-garden',
    'frame-angel-wings',
    'frame-diamond-ice-vip',
    'frame-flame-king-vip',
    'frame-india-pride',
    'frame-winner-trophy',
  ];

  static const List<String> profileCardIds = <String>[
    'profile-card-royal-gold',
    'profile-card-pink-heart',
    'profile-card-crystal-star',
    'profile-card-vip-queen',
    'profile-card-family-leader',
    'profile-card-host',
    'profile-card-agency',
    'profile-card-india-pride',
    'profile-card-birthday',
    'profile-card-winner',
  ];

  static const List<String> entryIds = <String>[
    'entry-golden-sports-car',
    'entry-angel-wings',
    'entry-rose-love-castle',
    'entry-royal-lion',
    'entry-luxury-yacht',
    'entry-princess-castle',
    'entry-phoenix-fire',
    'entry-diamond-ice',
    'entry-rocket-star',
    'entry-winner-trophy',
  ];

  static bool isPremiumId(String? id) {
    final value = id ?? '';
    return frameIds.contains(value) ||
        profileCardIds.contains(value) ||
        entryIds.contains(value);
  }

  static PremiumEffectStyle resolve(String? id, {String? fallbackTitle}) {
    final value = (id ?? '').toLowerCase();
    if (value.contains('pink') || value.contains('heart') || value.contains('rose')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Rose Love',
        icon: Icons.favorite_rounded,
        colors: const <Color>[Color(0xFFFF3D91), Color(0xFFFF86C8), Color(0xFFFFD166)],
      );
    }
    if (value.contains('diamond') || value.contains('crystal') || value.contains('ice')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Diamond Ice',
        icon: Icons.diamond_rounded,
        colors: const <Color>[Color(0xFF8BE9FF), Color(0xFF4F7CFF), Color(0xFFF4FBFF)],
      );
    }
    if (value.contains('flame') || value.contains('phoenix') || value.contains('fire')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Phoenix Fire',
        icon: Icons.local_fire_department_rounded,
        colors: const <Color>[Color(0xFFFF3D00), Color(0xFFFF9F1C), Color(0xFFFFE066)],
      );
    }
    if (value.contains('india')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'India Pride',
        icon: Icons.flag_rounded,
        colors: const <Color>[Color(0xFFFF9933), Color(0xFFF8F8F8), Color(0xFF138808)],
      );
    }
    if (value.contains('winner') || value.contains('trophy')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Winner Trophy',
        icon: Icons.emoji_events_rounded,
        colors: const <Color>[Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFFFFF3C4)],
      );
    }
    if (value.contains('angel') || value.contains('wings')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Angel Wings',
        icon: Icons.air_rounded,
        colors: const <Color>[Color(0xFFFFFFFF), Color(0xFF9EDBFF), Color(0xFFFFD54F)],
      );
    }
    if (value.contains('car')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Golden Sports Car',
        icon: Icons.directions_car_filled_rounded,
        colors: const <Color>[Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFF6D4C00)],
      );
    }
    if (value.contains('yacht')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Luxury Yacht',
        icon: Icons.directions_boat_filled_rounded,
        colors: const <Color>[Color(0xFFFFE082), Color(0xFF7FDBFF), Color(0xFFFFFFFF)],
      );
    }
    if (value.contains('lion')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Royal Lion',
        icon: Icons.pets_rounded,
        colors: const <Color>[Color(0xFFFFD54F), Color(0xFFA85D00), Color(0xFFFFF2B3)],
      );
    }
    if (value.contains('castle') || value.contains('princess')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Princess Castle',
        icon: Icons.account_balance_rounded,
        colors: const <Color>[Color(0xFFFF70C8), Color(0xFF9C6BFF), Color(0xFFFFD54F)],
      );
    }
    if (value.contains('rocket') || value.contains('star')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Rocket Star',
        icon: value.contains('rocket') ? Icons.rocket_launch_rounded : Icons.star_rounded,
        colors: const <Color>[Color(0xFF6C63FF), Color(0xFFE040FB), Color(0xFF63E6FF)],
      );
    }
    if (value.contains('birthday')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Birthday',
        icon: Icons.cake_rounded,
        colors: const <Color>[Color(0xFFFF66C4), Color(0xFF9C6BFF), Color(0xFFFFD54F)],
      );
    }
    if (value.contains('family')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Family Leader',
        icon: Icons.groups_rounded,
        colors: const <Color>[Color(0xFFFFD54F), Color(0xFFFF5C8A), Color(0xFF6C63FF)],
      );
    }
    if (value.contains('host')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Host',
        icon: Icons.mic_rounded,
        colors: const <Color>[Color(0xFFFF4FD8), Color(0xFF7C4DFF), Color(0xFFFFD54F)],
      );
    }
    if (value.contains('agency')) {
      return PremiumEffectStyle(
        id: id ?? '',
        title: fallbackTitle ?? 'Agency',
        icon: Icons.business_center_rounded,
        colors: const <Color>[Color(0xFF42A5F5), Color(0xFF7C4DFF), Color(0xFFFFD54F)],
      );
    }
    return PremiumEffectStyle(
      id: id ?? '',
      title: fallbackTitle ?? 'Royal Gold',
      icon: value.contains('vip') || value.contains('queen') || value.contains('crown')
          ? Icons.workspace_premium_rounded
          : Icons.auto_awesome_rounded,
      colors: const <Color>[Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFFFFF8E1)],
    );
  }
}

class PremiumEffectThumbnail extends StatelessWidget {
  const PremiumEffectThumbnail({
    super.key,
    required this.effectId,
    required this.title,
    this.size = 62,
  });

  final String effectId;
  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = PremiumEffectStyle.resolve(effectId, fallbackTitle: title);
    return Container(
      key: Key('premium-thumb-' + effectId),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: <Color>[...style.colors, style.colors.first]),
        boxShadow: <BoxShadow>[
          BoxShadow(color: style.colors.first.withValues(alpha: .42), blurRadius: 14, spreadRadius: 1),
        ],
      ),
      child: Center(
        child: Container(
          width: size * .76,
          height: size * .76,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xEE070503)),
          child: Icon(style.icon, color: style.colors.first, size: size * .42),
        ),
      ),
    );
  }
}

class PremiumEffectPreview extends StatefulWidget {
  const PremiumEffectPreview({
    super.key,
    required this.effectId,
    required this.title,
    this.height = 220,
  });

  final String effectId;
  final String title;
  final double height;

  @override
  State<PremiumEffectPreview> createState() => _PremiumEffectPreviewState();
}

class _PremiumEffectPreviewState extends State<PremiumEffectPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = PremiumEffectStyle.resolve(widget.effectId, fallbackTitle: widget.title);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final drift = math.sin(t * math.pi * 2) * 8;
        return Container(
          key: Key('premium-preview-' + widget.effectId),
          height: widget.height,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, -1),
              end: Alignment(1 - t * 2, 1),
              colors: <Color>[
                const Color(0xFF030201),
                style.colors.first.withValues(alpha: .20),
                style.colors[1].withValues(alpha: .16),
                const Color(0xFF030201),
              ],
            ),
            border: Border.all(color: style.colors.first, width: 1.4),
            boxShadow: <BoxShadow>[
              BoxShadow(color: style.colors.first.withValues(alpha: .34), blurRadius: 22, spreadRadius: 2),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(child: CustomPaint(painter: _PremiumParticlesPainter(t, style.colors))),
              Transform.translate(
                offset: Offset(drift, math.cos(t * math.pi * 2) * 4),
                child: Transform.scale(
                  scale: .96 + .05 * math.sin(t * math.pi * 2),
                  child: Container(
                    width: widget.height * .46,
                    height: widget.height * .46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        transform: GradientRotation(t * math.pi * 2),
                        colors: <Color>[...style.colors, style.colors.first],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: style.colors.first.withValues(alpha: .55), blurRadius: 30, spreadRadius: 4),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: widget.height * .34,
                        height: widget.height * .34,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xEE080604)),
                        child: Icon(style.icon, color: style.colors.last, size: widget.height * .18),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 13,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xD9000000),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: style.colors.first.withValues(alpha: .72)),
                  ),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: style.colors.last, fontWeight: FontWeight.w900, letterSpacing: .5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PremiumProfileCardShell extends StatefulWidget {
  const PremiumProfileCardShell({
    super.key,
    required this.effectId,
    required this.child,
  });

  final String? effectId;
  final Widget child;

  @override
  State<PremiumProfileCardShell> createState() => _PremiumProfileCardShellState();
}

class _PremiumProfileCardShellState extends State<PremiumProfileCardShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.effectId;
    if (id == null || id.isEmpty) return widget.child;
    final style = PremiumEffectStyle.resolve(id);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: <Widget>[
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _PremiumCardBorderPainter(t, style.colors)),
                ),
              ),
              Positioned(
                top: -80,
                left: -120 + 420 * t,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: -.35,
                    child: Container(
                      width: 70,
                      height: 280,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            style.colors.last.withValues(alpha: .22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PremiumEntranceOverlay extends StatefulWidget {
  const PremiumEntranceOverlay({
    super.key,
    required this.entryId,
    required this.displayName,
    required this.onFinished,
    this.avatarDataUrl,
  });

  final String entryId;
  final String displayName;
  final String? avatarDataUrl;
  final VoidCallback onFinished;

  @override
  State<PremiumEntranceOverlay> createState() => _PremiumEntranceOverlayState();
}

class _PremiumEntranceOverlayState extends State<PremiumEntranceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  Timer? finishTimer;

  @override
  void initState() {
    super.initState();
    controller.forward();
    finishTimer = Timer(const Duration(milliseconds: 3450), widget.onFinished);
  }

  @override
  void dispose() {
    finishTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  ImageProvider? get avatar {
    final value = widget.avatarDataUrl ?? '';
    if (!value.startsWith('data:image/')) return null;
    try {
      return MemoryImage(base64Decode(value.split(',').last));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = PremiumEffectStyle.resolve(widget.entryId);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final raw = controller.value;
          final t = Curves.easeOutCubic.transform((raw / .82).clamp(0.0, 1.0));
          final fade = raw < .78
              ? 1.0
              : (1 - ((raw - .78) / .22)).clamp(0.0, 1.0);
          final slide = (1 - t) * MediaQuery.sizeOf(context).width * .82;
          final pulse = 1 + math.sin(raw * math.pi * 6) * .035;
          return Opacity(
            opacity: fade,
            child: Container(
              key: Key('premium-entrance-' + widget.entryId),
              color: const Color(0x66000000),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned.fill(child: CustomPaint(painter: _PremiumParticlesPainter(raw, style.colors, dense: true))),
                  Transform.translate(
                    offset: Offset(slide, -22),
                    child: Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: math.min(MediaQuery.sizeOf(context).width * .84, 440),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            colors: <Color>[
                              const Color(0xF30A0704),
                              style.colors.first.withValues(alpha: .34),
                              const Color(0xF30A0704),
                            ],
                          ),
                          border: Border.all(color: style.colors.first, width: 1.5),
                          boxShadow: <BoxShadow>[
                            BoxShadow(color: style.colors.first.withValues(alpha: .60), blurRadius: 34, spreadRadius: 5),
                            BoxShadow(color: style.colors[1].withValues(alpha: .34), blurRadius: 54, spreadRadius: 8),
                          ],
                        ),
                        child: Row(
                          children: <Widget>[
                            Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: CircularProgressIndicator(
                                    value: raw,
                                    strokeWidth: 5,
                                    color: style.colors.first,
                                    backgroundColor: style.colors[1].withValues(alpha: .18),
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: const Color(0xFF111111),
                                  backgroundImage: avatar,
                                  child: avatar == null
                                      ? Icon(style.icon, color: style.colors.last, size: 34)
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Icon(style.icon, color: style.colors.first, size: 27),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          style.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: style.colors.last, fontWeight: FontWeight.w900, fontSize: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    widget.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'entered the room',
                                    style: TextStyle(color: Color(0xFFFFE9A8), fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PremiumParticlesPainter extends CustomPainter {
  _PremiumParticlesPainter(this.t, this.colors, {this.dense = false});

  final double t;
  final List<Color> colors;
  final bool dense;

  @override
  void paint(Canvas canvas, Size size) {
    final count = dense ? 32 : 18;
    for (var i = 0; i < count; i++) {
      final seed = i * 17.0;
      final width = math.max(1.0, size.width);
      final height = math.max(1.0, size.height);
      final x = ((seed * 31 + t * width * (18 + i % 7)) % (width + 20)) - 10;
      final baseY = (seed * 13) % height;
      final y = (baseY - t * (40 + (i % 5) * 16)) % height;
      final radius = 1.2 + (i % 4) * .7;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(
          alpha: (.36 + .12 * math.sin(t * math.pi * 2 + i)).clamp(0.12, 0.55),
        );
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumParticlesPainter oldDelegate) => oldDelegate.t != t;
}

class _PremiumCardBorderPainter extends CustomPainter {
  _PremiumCardBorderPainter(this.t, this.colors);
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(1.2), const Radius.circular(14));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..shader = SweepGradient(
        transform: GradientRotation(t * math.pi * 2),
        colors: <Color>[...colors, colors.first],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
      ..color = colors.first.withValues(alpha: .28);
    canvas.drawRRect(rrect, glow);
  }

  @override
  bool shouldRepaint(covariant _PremiumCardBorderPainter oldDelegate) => oldDelegate.t != t;
}
