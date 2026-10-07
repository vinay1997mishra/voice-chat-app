import 'package:flutter/material.dart';

abstract final class RoyalPalette {
  // Midnight blue surfaces, readable text and restrained champagne accents.
  static const black = Color(0xFF0B1020);
  static const nearBlack = Color(0xFF101729);
  static const panel = Color(0xFF172136);
  static const panel2 = Color(0xFF202D45);
  static const gold = Color(0xFFE8C36A);
  static const deepGold = Color(0xFF9B7428);
  static const bronze = Color(0xFF42516B);
  static const cream = Color(0xFFF3F5FC);
  static const muted = Color(0xFFAAB7CC);
}

abstract final class FeaturePalette {
  // Jewel accents: each module keeps its identity without turning the UI neon.
  static const cp = Color(0xFFED739E);
  static const cpSoft = Color(0xFFFFBAD0);
  static const vip = Color(0xFF5B78B8);
  static const gift = Color(0xFF8B62A8);
  static const family = Color(0xFF4A9878);
  static const games = Color(0xFFC47A43);
  static const music = Color(0xFF4F95A0);
  static const social = Color(0xFF5F82B4);
  static const discover = Color(0xFF5B93A8);
  static const message = Color(0xFF4F917F);
  static const email = Color(0xFFC59352);
  static const facebook = Color(0xFF5874AF);
  static const google = Color(0xFF6682B2);
  static const wallet = Color(0xFFD2A64E);
  static const store = Color(0xFFB86868);
  static const rank = Color(0xFFD0A640);
  static const moments = Color(0xFF746AA4);
  static const rocket = Color(0xFFB95C63);
  static const backpack = Color(0xFF60977C);
  static const customGift = Color(0xFFA76BAA);
  static const safety = Color(0xFFB95E5B);
  static const diamond = Color(0xFF61A3B7);
  static const ludo = Color(0xFF5D946B);
  static const uno = Color(0xFFB8574F);
  static const fruitParty = Color(0xFFB85E8A);

  static LinearGradient glow(Color color) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.16),
          RoyalPalette.panel,
          color.withValues(alpha: 0.055),
        ],
        stops: const [0.0, 0.54, 1.0],
      );
}

class ShiningIcon extends StatelessWidget {
  const ShiningIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 28,
    this.boxSize,
    this.glow = 0.20,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? boxSize;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final diameter = boxSize ?? size + 18;
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.055),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.52),
          width: 1.05,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: glow),
            blurRadius: 12,
            spreadRadius: 0.4,
          ),
          BoxShadow(
            color: color.withValues(alpha: glow * 0.45),
            blurRadius: 20,
            spreadRadius: 0.3,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

ThemeData buildRoyalTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: RoyalPalette.gold,
    brightness: Brightness.dark,
    primary: RoyalPalette.gold,
    secondary: RoyalPalette.cream,
    surface: RoyalPalette.panel,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: RoyalPalette.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: RoyalPalette.black,
      foregroundColor: RoyalPalette.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: RoyalPalette.nearBlack,
      indicatorColor: RoyalPalette.deepGold.withValues(alpha: 0.28),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? RoyalPalette.gold
              : RoyalPalette.muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? RoyalPalette.gold
              : RoyalPalette.muted,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: RoyalPalette.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RoyalPalette.bronze),
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RoyalPalette.nearBlack,
      labelStyle: const TextStyle(color: RoyalPalette.cream),
      hintStyle: const TextStyle(color: RoyalPalette.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: RoyalPalette.bronze),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: RoyalPalette.gold, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RoyalPalette.gold,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RoyalPalette.gold,
        side: const BorderSide(color: RoyalPalette.deepGold),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: RoyalPalette.panel2,
      selectedColor: RoyalPalette.deepGold,
      side: BorderSide(color: RoyalPalette.bronze),
      labelStyle: TextStyle(color: RoyalPalette.cream),
    ),
    dividerColor: RoyalPalette.bronze,
  );
}

class RoyalPanel extends StatelessWidget {
  const RoyalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.gradient,
    this.accentColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Gradient? gradient;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? RoyalPalette.deepGold;
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? RoyalPalette.panel : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent.withValues(
            alpha: accentColor == null ? 0.72 : 0.48,
          ),
          width: accentColor == null ? 1.0 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(
              alpha: accentColor == null ? 0.07 : 0.13,
            ),
            blurRadius: accentColor == null ? 16 : 17,
            spreadRadius: accentColor == null ? 0.4 : 0.6,
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: body,
    );
  }
}

class GoldSectionTitle extends StatelessWidget {
  const GoldSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: RoyalPalette.cream,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}
