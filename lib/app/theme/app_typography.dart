import 'package:material_ui/material_ui.dart';
import 'package:kaya/app/theme/app_colors.dart';

/// Centralized typography tokens for the KAYA Design System.
///
/// Enforces readable font sizes (no tiny text < 12sp) and clear visual hierarchy.
abstract final class AppTypography {
  static const String primaryFontFamily = 'Inter';
  static const List<String> fontFamilyFallback = <String>[
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static TextTheme get textTheme => const TextTheme(
    displayLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    displayMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      height: 1.25,
      color: AppColors.textPrimary,
    ),
    displaySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.3,
      color: AppColors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.3,
      color: AppColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.35,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.4,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: AppColors.textSecondary,
    ),
    bodyLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.3,
      color: AppColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.3,
      color: AppColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontFamily: primaryFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      height: 1.3,
      color: AppColors.textMuted,
    ),
  );
}
