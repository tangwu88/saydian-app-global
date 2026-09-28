import 'package:flutter/material.dart';

abstract final class SaydianColors {
  // Legacy field names remain for existing pages; the brand accent is black.
  // Health warnings use the separate semantic danger color below.
  static const brandRed = Color(0xFF17191C);
  static const brandRedDark = Color(0xFF111214);
  static const brandGold = Color(0xFFD6B35A);
  static const brandGoldDark = Color(0xFF705300);
  static const goldText = brandGoldDark;
  static const brandRedSoft = Color(0xFFF0F1F2);
  static const brandGoldSoft = Color(0xFFFFF6DE);

  static const ink = Color(0xFF17191C);
  static const muted = Color(0xFF5D646B);
  static const canvas = Color(0xFFF8F8F6);
  static const line = Color(0xFFE8E8E5);
  static const outline = Color(0xFF98A2B3);
  static const techBlue = Color(0xFF316EF5);
  static const techBlueSoft = Color(0xFFEAF1FF);

  // Subtle color cues echo the cool, airy U19S imagery on saydian.com while
  // leaving the logo, primary actions, and reading values high-contrast.
  static const sky = Color(0xFF276782);
  static const skySoft = Color(0xFFEAF4F8);
  static const sage = Color(0xFF367360);
  static const sageSoft = Color(0xFFEDF5F0);
  static const clay = Color(0xFFA45D45);
  static const claySoft = Color(0xFFFAF0EA);

  // Semantic colors stay independent from the brand palette. This keeps a
  // successful/normal state green and a warning amber after the chrome turns
  // black and silver. All are dark enough for text on white.
  static const success = Color(0xFF287A3B);
  static const info = Color(0xFF2467A6);
  static const warning = Color(0xFF8A4B00);
  static const danger = Color(0xFFB3261E);
  static const heart = Color(0xFFA83C5A);
  static const temperature = Color(0xFF146A75);

  // Backwards-compatible metric aliases used by the existing pages.
  static const green = success;
  static const blue = info;
  static const orange = warning;
  static const pink = heart;
  static const cyan = temperature;
}

ThemeData buildSaydianTheme() {
  const scheme = ColorScheme.light(
    primary: SaydianColors.brandRed,
    onPrimary: Colors.white,
    primaryContainer: SaydianColors.brandRedSoft,
    onPrimaryContainer: SaydianColors.brandRedDark,
    secondary: SaydianColors.goldText,
    onSecondary: Colors.white,
    secondaryContainer: SaydianColors.brandGoldSoft,
    onSecondaryContainer: SaydianColors.ink,
    surface: Colors.white,
    onSurface: SaydianColors.ink,
    error: SaydianColors.danger,
    onError: Colors.white,
    outline: SaydianColors.outline,
    outlineVariant: SaydianColors.line,
  );

  const textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 34, height: 1.2),
    displayMedium: TextStyle(fontSize: 31, height: 1.22),
    displaySmall: TextStyle(fontSize: 28, height: 1.25),
    headlineLarge: TextStyle(
      fontSize: 24,
      height: 1.28,
      fontWeight: FontWeight.w800,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w800,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      height: 1.32,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.35,
      fontWeight: FontWeight.w800,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: TextStyle(fontSize: 17, height: 1.55),
    bodyMedium: TextStyle(fontSize: 16, height: 1.5),
    bodySmall: TextStyle(fontSize: 14, height: 1.45),
    labelLarge: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: SaydianColors.canvas,
    useMaterial3: true,
    fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'sans-serif'],
    textTheme: textTheme.apply(
      bodyColor: SaydianColors.ink,
      displayColor: SaydianColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: SaydianColors.canvas,
      foregroundColor: SaydianColors.ink,
      titleTextStyle: TextStyle(
        color: SaydianColors.ink,
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: SaydianColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: SaydianColors.muted, fontSize: 16),
      labelStyle: const TextStyle(color: SaydianColors.muted, fontSize: 16),
      helperStyle: const TextStyle(color: SaydianColors.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SaydianColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SaydianColors.brandRed, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SaydianColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SaydianColors.danger, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        foregroundColor: SaydianColors.ink,
        side: const BorderSide(color: SaydianColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        foregroundColor: SaydianColors.brandRed,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        iconSize: 24,
        foregroundColor: SaydianColors.ink,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: SaydianColors.brandRed,
      textColor: SaydianColors.ink,
      minVerticalPadding: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleTextStyle: TextStyle(
        color: SaydianColors.ink,
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: TextStyle(
        color: SaydianColors.muted,
        fontSize: 14,
        height: 1.45,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: SaydianColors.line,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: Colors.transparent,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? SaydianColors.brandRed
              : SaydianColors.muted,
          size: states.contains(WidgetState.selected) ? 26 : 25,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? SaydianColors.brandRed
              : SaydianColors.muted,
          fontSize: 12.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: SaydianColors.brandRed,
      linearTrackColor: SaydianColors.brandRedSoft,
      circularTrackColor: SaydianColors.brandRedSoft,
    ),
  );
}

const saydianSoftGradient = LinearGradient(
  colors: [Color(0xFFFFFFFF), SaydianColors.canvas, Color(0xFFE8EBED)],
  stops: [0, 0.5, 1],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
