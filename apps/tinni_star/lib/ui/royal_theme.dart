import 'package:flutter/material.dart';

abstract final class RoyalPalette {
  static const black = Color(0xFF050505);
  static const nearBlack = Color(0xFF0D0B08);
  static const panel = Color(0xFF15110B);
  static const panel2 = Color(0xFF21190D);
  static const gold = Color(0xFFFFD45A);
  static const deepGold = Color(0xFFB8860B);
  static const bronze = Color(0xFF7A5515);
  static const cream = Color(0xFFFFE9A6);
  static const muted = Color(0xFFB8A77A);
}

abstract final class FeaturePalette {
  // Black + gold remain the app shell/background identity.
  // Functional modules use their own accent colors so the UI is not
  // monochrome and important actions are easier to recognize.
  static const cp = Color(0xFFFF4D8D);
  static const cpSoft = Color(0xFFFF8FB7);
  static const vip = Color(0xFF5B8CFF);
  static const gift = Color(0xFFB45CFF);
  static const family = Color(0xFF26C78D);
  static const games = Color(0xFFFF8A3D);
  static const music = Color(0xFF28C7D9);
  static const social = Color(0xFF4F9DFF);
  static const wallet = Color(0xFFFFC247);
  static const store = Color(0xFFFF6B6B);
  static const rank = Color(0xFFFFB300);
  static const moments = Color(0xFF7C6CFF);
  static const rocket = Color(0xFFFF5A65);
  static const backpack = Color(0xFF45C08A);
  static const customGift = Color(0xFFE86CFF);
  static const safety = Color(0xFFEF5350);
  static const diamond = Color(0xFF49D7FF);
  static const ludo = Color(0xFF34C759);
  static const uno = Color(0xFFFF3B30);
  static const fruitJackpot = Color(0xFFFFC107);
  static const fruitParty = Color(0xFFFF4DB8);

  static LinearGradient glow(Color color) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.30),
          RoyalPalette.panel,
          color.withValues(alpha: 0.12),
        ],
      );
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
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? RoyalPalette.panel : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: RoyalPalette.deepGold, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: RoyalPalette.deepGold.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: 1,
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
