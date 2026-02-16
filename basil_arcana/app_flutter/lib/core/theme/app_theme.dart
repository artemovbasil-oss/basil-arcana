import 'package:flutter/material.dart';

enum AppThemeFlavor {
  defaultTheme,
  crowley,
}

ThemeData buildAppTheme({AppThemeFlavor flavor = AppThemeFlavor.defaultTheme}) {
  final palette = _paletteForFlavor(flavor);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: palette.primary,
    onPrimary: Colors.white,
    onPrimaryContainer: Colors.white,
    background: palette.background,
    surface: palette.surface,
    surfaceVariant: palette.surfaceVariant,
    outlineVariant: palette.outlineVariant,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: palette.background,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: palette.primary.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: palette.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: palette.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide:
            BorderSide(color: palette.primary.withOpacity(0.9), width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surfaceVariant,
      selectedColor: palette.primary.withOpacity(0.2),
      secondarySelectedColor: palette.primary.withOpacity(0.2),
      labelStyle: TextStyle(color: colorScheme.onSurface),
      side: BorderSide(color: palette.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: palette.primary.withOpacity(0.4),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: palette.primary,
        side: BorderSide(color: palette.primary.withOpacity(0.7)),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        minimumSize: const Size.fromHeight(54),
        shape: const StadiumBorder(),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: palette.outlineVariant.withOpacity(0.8),
      thickness: 1,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, height: 1.3),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );
}

class _ThemePalette {
  const _ThemePalette({
    required this.primary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.outlineVariant,
  });

  final Color primary;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color outlineVariant;
}

_ThemePalette _paletteForFlavor(AppThemeFlavor flavor) {
  switch (flavor) {
    case AppThemeFlavor.crowley:
      return const _ThemePalette(
        primary: Color(0xFF9A8D77),
        background: Color(0xFF181818),
        surface: Color(0xFF212121),
        surfaceVariant: Color(0xFF2A2A2A),
        outlineVariant: Color(0xFF484848),
      );
    case AppThemeFlavor.defaultTheme:
      return const _ThemePalette(
        primary: Color(0xFF9B5CFF),
        background: Color(0xFF121212),
        surface: Color(0xFF1C1B1F),
        surfaceVariant: Color(0xFF27222F),
        outlineVariant: Color(0xFF3A3247),
      );
  }
}
