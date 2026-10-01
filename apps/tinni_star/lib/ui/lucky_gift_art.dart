import 'dart:math' as math;

import 'package:flutter/material.dart';

class LuckyGiftArt extends StatelessWidget {
  const LuckyGiftArt({
    super.key,
    required this.giftId,
    this.size = 58,
    this.showHalo = true,
  });

  final String giftId;
  final double size;
  final bool showHalo;

  static IconData iconFor(String giftId) {
    switch (giftId) {
      case 'lucky-colorful-rose':
        return Icons.local_florist_rounded;
      case 'lucky-rainbow-heart':
        return Icons.favorite_rounded;
      case 'lucky-magic-balloon':
        return Icons.celebration_rounded;
      case 'lucky-candy-star':
        return Icons.star_rounded;
      case 'lucky-neon-butterfly':
        return Icons.auto_awesome_rounded;
      case 'lucky-sparkle-crown':
        return Icons.workspace_premium_rounded;
      case 'lucky-dream-cake':
        return Icons.cake_rounded;
      case 'lucky-galaxy-ring':
        return Icons.diamond_rounded;
      case 'lucky-shining-unicorn':
        return Icons.pets_rounded;
      case 'lucky-royal-treasure':
        return Icons.inventory_2_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  static List<Color> paletteFor(String giftId) {
    switch (giftId) {
      case 'lucky-colorful-rose':
        return const [Color(0xFFFF4FA3), Color(0xFF7C4DFF), Color(0xFFFFC247)];
      case 'lucky-rainbow-heart':
        return const [Color(0xFFFF3D8D), Color(0xFFFF8ACB), Color(0xFF6FE8FF)];
      case 'lucky-magic-balloon':
        return const [Color(0xFF50D8FF), Color(0xFF8B5CFF), Color(0xFFFF5EC9)];
      case 'lucky-candy-star':
        return const [Color(0xFFFF3D8D), Color(0xFFFFB52E), Color(0xFF42E8B4)];
      case 'lucky-neon-butterfly':
        return const [Color(0xFF45F4FF), Color(0xFF8E5BFF), Color(0xFFFF4BD2)];
      case 'lucky-sparkle-crown':
        return const [Color(0xFFFFD95A), Color(0xFFFF7C32), Color(0xFF9B63FF)];
      case 'lucky-dream-cake':
        return const [Color(0xFFFF84D6), Color(0xFF7E6CFF), Color(0xFFFFD76B)];
      case 'lucky-galaxy-ring':
        return const [Color(0xFF3B6BFF), Color(0xFF9D4DFF), Color(0xFFFF4FC3)];
      case 'lucky-shining-unicorn':
        return const [Color(0xFFFF72D8), Color(0xFF59DFFF), Color(0xFFFFD754)];
      case 'lucky-royal-treasure':
        return const [Color(0xFFFFC247), Color(0xFF9A4DFF), Color(0xFFFF4F9D)];
      default:
        return const [Color(0xFFFFC247), Color(0xFFFF6A4D), Color(0xFF7C4DFF)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteFor(giftId);
    final icon = iconFor(giftId);
    final outer = size;
    final core = size * 0.78;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (showHalo)
            Container(
              width: outer * 0.92,
              height: outer * 0.92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    palette[0].withValues(alpha: 0.34),
                    palette[1].withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          Transform.rotate(
            angle: -0.10,
            child: Container(
              width: core,
              height: core,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(core * 0.30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette[0],
                    palette[1],
                    palette[2],
                    palette[0],
                  ],
                  stops: const [0.0, 0.36, 0.72, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xFFFFEBA0),
                  width: math.max(1.2, size * 0.035),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette[0].withValues(alpha: 0.62),
                    blurRadius: size * 0.20,
                    spreadRadius: size * 0.02,
                    offset: Offset(0, size * 0.08),
                  ),
                  BoxShadow(
                    color: const Color(0xAAFFD45A),
                    blurRadius: size * 0.10,
                    offset: Offset(-size * 0.05, -size * 0.05),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: core * 0.10,
                    top: core * 0.08,
                    width: core * 0.56,
                    height: core * 0.28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(core),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.70),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFFFF3B0),
                          Color(0xFFFFC247),
                          Color(0xFFFFFFFF),
                        ],
                      ).createShader(rect),
                      child: Icon(
                        icon,
                        size: core * 0.56,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.40),
                            blurRadius: size * 0.09,
                            offset: Offset(0, size * 0.055),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: core * 0.09,
                    bottom: core * 0.09,
                    child: _Jewel(
                      size: core * 0.19,
                      colors: [palette[2], palette[0]],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: size * 0.02,
            top: size * 0.10,
            child: _Sparkle(size: size * 0.25),
          ),
          Positioned(
            right: -size * 0.01,
            top: size * 0.25,
            child: _Sparkle(size: size * 0.18),
          ),
          Positioned(
            right: size * 0.12,
            bottom: size * 0.02,
            child: _Sparkle(size: size * 0.15),
          ),
        ],
      ),
    );
  }
}

class LuckyGiftFlightArt extends StatelessWidget {
  const LuckyGiftFlightArt({
    super.key,
    required this.giftId,
    required this.progress,
    required this.size,
  });

  final String giftId;
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = LuckyGiftArt.paletteFor(giftId);
    return SizedBox(
      width: size * 1.8,
      height: size * 1.3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: size * 0.05,
            right: size * 0.44,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                height: size * 0.22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      palette[1].withValues(alpha: 0.20),
                      palette[0].withValues(alpha: 0.60),
                      const Color(0xFFFFD45A).withValues(alpha: 0.92),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette[0].withValues(alpha: 0.38),
                      blurRadius: size * 0.22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: size * 0.18,
            top: size * 0.20,
            child: _Sparkle(size: size * 0.22),
          ),
          Positioned(
            left: size * 0.36,
            bottom: size * 0.18,
            child: _Sparkle(size: size * 0.15),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Transform.rotate(
              angle: (1 - progress) * -0.55,
              child: LuckyGiftArt(
                giftId: giftId,
                size: size,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LuckyGiftImpactArt extends StatelessWidget {
  const LuckyGiftImpactArt({
    super.key,
    required this.giftId,
    required this.progress,
    required this.size,
  });

  final String giftId;
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = LuckyGiftArt.paletteFor(giftId);
    final fade = (1 - progress).clamp(0.0, 1.0).toDouble();
    return Opacity(
      opacity: fade,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * (0.28 + progress * 0.62),
              height: size * (0.28 + progress * 0.62),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFE46A).withValues(alpha: fade),
                  width: math.max(1.0, size * 0.025),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette[0].withValues(alpha: 0.55 * fade),
                    blurRadius: size * 0.24,
                    spreadRadius: size * 0.07,
                  ),
                ],
              ),
            ),
            for (var i = 0; i < 8; i++)
              Transform.rotate(
                angle: i * math.pi / 4,
                child: Transform.translate(
                  offset: Offset(0, -size * (0.08 + progress * 0.38)),
                  child: _Sparkle(
                    size: size * (i.isEven ? 0.18 : 0.12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LuckyMultiplierBadge extends StatelessWidget {
  const LuckyMultiplierBadge({
    super.key,
    required this.multiplier,
    this.compact = false,
  });

  final int multiplier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rare = multiplier >= 200;
    final width = compact ? 52.0 : 68.0;
    final height = compact ? 31.0 : 38.0;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: LinearGradient(
          colors: rare
              ? const [
                  Color(0xFFFFF2A3),
                  Color(0xFFFFA322),
                  Color(0xFFFF425C),
                  Color(0xFF7D2DFF),
                ]
              : const [
                  Color(0xFF63E9FF),
                  Color(0xFF7654FF),
                  Color(0xFFFF51D0),
                  Color(0xFFFFC247),
                ],
        ),
        border: Border.all(
          color: const Color(0xFFFFF0A0),
          width: rare ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (rare ? const Color(0xFFFF9B22) : const Color(0xFFB75CFF))
                .withValues(alpha: 0.65),
            blurRadius: rare ? 16 : 10,
            spreadRadius: rare ? 2 : 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 7,
            top: 4,
            width: width * 0.55,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
          ),
          Text(
            '$multiplier×',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 13 : 17,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(
                  color: Color(0xAA4A1800),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LuckyComboOrb extends StatelessWidget {
  const LuckyComboOrb({
    super.key,
    required this.loading,
  });

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.30, -0.38),
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFE568),
            Color(0xFFFF7FBF),
            Color(0xFF8B55FF),
            Color(0xFF281040),
          ],
          stops: [0.0, 0.18, 0.46, 0.72, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFFFFE879),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88FF5FDB),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Color(0x88FFD45A),
            blurRadius: 8,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 5,
            left: 10,
            child: _Sparkle(size: 14),
          ),
          if (loading)
            const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            const Text(
              'COMBO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                shadows: [
                  Shadow(
                    color: Color(0xAA53156F),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome_rounded,
      size: size,
      color: const Color(0xFFFFF1A8),
      shadows: const [
        Shadow(color: Color(0xFFFFC247), blurRadius: 7),
        Shadow(color: Color(0xFFFF5BD4), blurRadius: 12),
      ],
    );
  }
}

class _Jewel extends StatelessWidget {
  const _Jewel({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: [
            Colors.white,
            colors.first,
            colors.last,
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFED9A),
          width: math.max(0.8, size * 0.09),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.65),
            blurRadius: size * 0.45,
          ),
        ],
      ),
    );
  }
}
