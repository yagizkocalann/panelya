import 'package:flutter/material.dart';

import 'tokens.dart';

/// [AppTokens]'tan Material 3 [ThemeData] üretir. Panelya'da yalnızca koyu
/// tema vardır (docs/mobile-handoff.md); bu yüzden burada tek bir
/// `buildAppTheme` fonksiyonu bulunur, light tema karşılığı yoktur.
ThemeData buildAppTheme() {
  final tokens = AppTokens.dark;
  final colors = tokens.colors;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.mint,
    brightness: Brightness.dark,
  ).copyWith(
    primary: colors.mint,
    onPrimary: colors.background,
    secondary: colors.mintStrong,
    surface: colors.surface,
    onSurface: colors.ink,
    error: colors.coral,
    outline: colors.line,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: colors.background,
    colorScheme: colorScheme,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: tokens.typography.titleLarge,
    ),
    textTheme: TextTheme(
      headlineLarge: tokens.typography.displayLarge,
      titleLarge: tokens.typography.titleLarge,
      titleMedium: tokens.typography.titleMedium,
      bodyLarge: tokens.typography.bodyLarge,
      bodyMedium: tokens.typography.bodyMedium,
      bodySmall: tokens.typography.bodySmall,
      labelLarge: tokens.typography.label,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.mint,
        foregroundColor: colors.background,
        minimumSize: Size(double.infinity, tokens.sizes.minTouchTarget),
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.md),
        ),
        textStyle: tokens.typography.label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.ink,
        minimumSize: Size(double.infinity, tokens.sizes.minTouchTarget),
        side: BorderSide(color: colors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.md),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: Size(
          tokens.sizes.minTouchTarget,
          tokens.sizes.minTouchTarget,
        ),
        foregroundColor: colors.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        side: BorderSide(color: colors.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.line, space: 1),
    listTileTheme: ListTileThemeData(iconColor: colors.muted),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.surface3,
      contentTextStyle: tokens.typography.bodyMedium.copyWith(
        color: colors.ink,
      ),
    ),
  );
}
