import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/core/theme/app_fonts.dart';
import 'package:spor_takip/core/theme/app_theme.dart';

void main() {
  final theme = AppTheme.dark();

  test('is a dark theme on the background color', () {
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.surface, AppColors.background);
  });

  test('maps the palette onto the color scheme', () {
    final scheme = theme.colorScheme;
    expect(scheme.primary, AppColors.accent);
    expect(scheme.onPrimary, AppColors.onAccent);
    expect(scheme.surfaceContainer, AppColors.surface);
    expect(scheme.onSurfaceVariant, AppColors.muted);
    expect(scheme.outlineVariant, AppColors.line);
    expect(scheme.error, AppColors.error);
  });

  test('headings use Montserrat, body text uses Inter', () {
    expect(theme.textTheme.headlineSmall!.fontFamily, AppFonts.heading);
    expect(theme.textTheme.titleLarge!.fontFamily, AppFonts.heading);
    expect(theme.textTheme.bodyMedium!.fontFamily, AppFonts.body);
    expect(theme.textTheme.titleMedium!.fontFamily, AppFonts.body);
  });

  test('cards are flat surface boxes with 16 radius', () {
    expect(theme.cardTheme.color, AppColors.surface);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
  });

  test('filled buttons are accent with dark text', () {
    final style = theme.filledButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), AppColors.accent);
    expect(style.foregroundColor!.resolve({}), AppColors.onAccent);
  });

  test('selected navigation items are accent, others muted', () {
    final icon = theme.navigationBarTheme.iconTheme!;
    expect(icon.resolve({WidgetState.selected})!.color, AppColors.accent);
    expect(icon.resolve({})!.color, AppColors.muted);
  });
}
