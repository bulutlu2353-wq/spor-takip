import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

/// Uygulamanın tek teması (spec §4.1): koyu zemin, neon yeşil vurgu.
abstract final class AppTheme {
  static const _radius12 = BorderRadius.all(Radius.circular(12));
  static const _radius16 = BorderRadius.all(Radius.circular(16));

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: AppColors.surfaceHigh,
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: AppColors.surfaceHigh,
      onSecondaryContainer: AppColors.accent,
      tertiary: AppColors.accent,
      onTertiary: AppColors.onAccent,
      error: AppColors.error,
      onError: AppColors.onAccent,
      surface: AppColors.background,
      onSurface: AppColors.text,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.line,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.muted,
      outlineVariant: AppColors.line,
      inverseSurface: AppColors.text,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.onAccent,
    );
    final textTheme = _textTheme();
    const buttonText = TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w800, letterSpacing: 0.6);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: _radius16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(borderRadius: _radius12),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.line),
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(borderRadius: _radius12),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent, textStyle: buttonText),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        shape: RoundedRectangleBorder(borderRadius: _radius16),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.accent, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.error, width: 2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        indicatorColor: AppColors.surfaceHigh,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppFonts.body,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted,
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.surfaceHigh,
        side: BorderSide(color: AppColors.line),
        labelStyle: TextStyle(color: AppColors.text),
        checkmarkColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: _radius12),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: _radius16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.surface),
      popupMenuTheme: const PopupMenuThemeData(color: AppColors.surfaceHigh),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.text),
        actionTextColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.line,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.muted),
    );
  }

  static TextTheme _textTheme() {
    final base = ThemeData(brightness: Brightness.dark).textTheme.apply(
          fontFamily: AppFonts.body,
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        );
    TextStyle? heading(TextStyle? style, FontWeight weight) =>
        style?.copyWith(fontFamily: AppFonts.heading, fontWeight: weight);
    TextStyle? body(TextStyle? style, FontWeight weight) => style?.copyWith(fontWeight: weight);
    return base.copyWith(
      displayLarge: heading(base.displayLarge, FontWeight.w900),
      displayMedium: heading(base.displayMedium, FontWeight.w900),
      displaySmall: heading(base.displaySmall, FontWeight.w900),
      headlineLarge: heading(base.headlineLarge, FontWeight.w900),
      headlineMedium: heading(base.headlineMedium, FontWeight.w900),
      headlineSmall: heading(base.headlineSmall, FontWeight.w800),
      titleLarge: heading(base.titleLarge, FontWeight.w800),
      titleMedium: body(base.titleMedium, FontWeight.w600),
      titleSmall: body(base.titleSmall, FontWeight.w600),
      labelLarge: body(base.labelLarge, FontWeight.w600),
    );
  }
}
