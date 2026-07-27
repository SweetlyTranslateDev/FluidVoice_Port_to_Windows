import 'package:flutter/material.dart';

/// Bundled UI font family (see pubspec fonts). Do not use "Segoe UI" by name —
/// Flutter Windows can resolve that to SegoeIcons and drop lowercase glyphs.
const String kFluidFontFamily = 'FluidUI';

/// macOS AppTheme-aligned tokens for the Windows Flutter shell.
abstract final class FluidColors {
  static const accent = Color(0xFF3AC8C6);
  // Slightly translucent so Win11 acrylic/mica can show through.
  static const windowBackground = Color(0xE0121212);
  static const contentBackground = Color(0xE6171717);
  static const sidebarBackground = Color(0xE00F0F0F);
  static const cardBackground = Color(0xF0141414);
  static const elevatedCardBackground = Color(0xF01C1C1C);
  static const toolbarBackground = Color(0xFF0F0F0F);
  static const cardBorder = Color(0x1AFFFFFF); // white @ 10%
  static const separator = Color(0x29FFFFFF); // white @ 16%
  static const primaryText = Color(0xFFF2F2F2);
  static const secondaryText = Color(0xFFA3A3A3);
  static const tertiaryText = Color(0xFF737373);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const success = accent;
}

abstract final class FluidSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

abstract final class FluidRadii {
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

TextStyle fluidText({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  FontStyle? fontStyle,
}) {
  return TextStyle(
    fontFamily: kFluidFontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
  );
}

ThemeData buildFluidVoiceTheme() {
  const accent = FluidColors.accent;
  final scheme = ColorScheme.dark(
    primary: accent,
    onPrimary: const Color(0xFF062221),
    secondary: accent,
    onSecondary: const Color(0xFF062221),
    surface: FluidColors.contentBackground,
    onSurface: FluidColors.primaryText,
    onSurfaceVariant: FluidColors.secondaryText,
    error: FluidColors.danger,
    onError: Colors.white,
    outline: FluidColors.cardBorder,
    outlineVariant: FluidColors.separator,
  );

  final textTheme = TextTheme(
    displayLarge: fluidText(
      fontSize: 42,
      fontWeight: FontWeight.w600,
      color: FluidColors.primaryText,
      height: 1.15,
    ),
    headlineMedium: fluidText(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: FluidColors.primaryText,
    ),
    titleLarge: fluidText(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: FluidColors.primaryText,
    ),
    titleMedium: fluidText(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: FluidColors.primaryText,
    ),
    bodyLarge: fluidText(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: FluidColors.primaryText,
      height: 1.4,
    ),
    bodyMedium: fluidText(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: FluidColors.primaryText,
      height: 1.4,
    ),
    bodySmall: fluidText(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: FluidColors.secondaryText,
    ),
    labelLarge: fluidText(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: FluidColors.primaryText,
    ),
    labelMedium: fluidText(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: FluidColors.secondaryText,
    ),
    labelSmall: fluidText(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: FluidColors.tertiaryText,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: FluidColors.contentBackground,
    canvasColor: FluidColors.contentBackground,
    dividerColor: FluidColors.separator,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    fontFamily: kFluidFontFamily,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: FluidColors.contentBackground,
      foregroundColor: FluidColors.primaryText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: fluidText(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: FluidColors.primaryText,
      ),
    ),
    cardTheme: CardThemeData(
      color: FluidColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FluidRadii.lg),
        side: const BorderSide(color: FluidColors.cardBorder),
      ),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: FluidColors.secondaryText,
      textColor: FluidColors.primaryText,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: FluidSpacing.lg),
      titleTextStyle: fluidText(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: FluidColors.primaryText,
      ),
      subtitleTextStyle: fluidText(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: FluidColors.secondaryText,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FluidColors.elevatedCardBackground,
      labelStyle: fluidText(color: FluidColors.secondaryText),
      hintStyle: fluidText(color: FluidColors.tertiaryText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluidRadii.md),
        borderSide: const BorderSide(color: FluidColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluidRadii.md),
        borderSide: const BorderSide(color: FluidColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluidRadii.md),
        borderSide: const BorderSide(color: accent, width: 1.4),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return FluidColors.secondaryText;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent.withValues(alpha: 0.35);
        }
        return FluidColors.elevatedCardBackground;
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return FluidColors.secondaryText;
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: const Color(0xFF062221),
        textStyle: fluidText(fontSize: 14, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(
          horizontal: FluidSpacing.xl,
          vertical: FluidSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FluidRadii.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: fluidText(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: FluidColors.elevatedCardBackground,
      contentTextStyle: fluidText(color: FluidColors.primaryText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FluidRadii.md),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(
      color: FluidColors.separator,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: fluidText(fontSize: 13, color: FluidColors.primaryText),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FluidColors.elevatedCardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FluidRadii.md),
        ),
      ),
    ),
  );
}
