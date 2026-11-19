import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/app/theme/app_theme.dart';
import 'package:kaya/app/theme/app_typography.dart';
import 'package:kaya/core/utils/responsive_layout.dart';

void main() {
  group('KAYA Design System Tokens', () {
    test('AppColors match Master Blueprint specifications', () {
      expect(AppColors.background, const Color(0xFF0D1117));
      expect(AppColors.surface, const Color(0xFF151B23));
      expect(AppColors.primary, const Color(0xFF6EE7B7));
      expect(AppColors.secondary, const Color(0xFF7DD3FC));
    });

    test('AppSpacing enforces minimum 48px touch target and 4pt/8pt scale', () {
      expect(AppSpacing.minTouchTarget, greaterThanOrEqualTo(48.0));
      expect(AppSpacing.xxs, 4.0);
      expect(AppSpacing.xs, 8.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
    });

    test('AppTypography enforces readable minimum font size (>= 12sp, no tiny text)', () {
      final TextTheme textTheme = AppTypography.textTheme;
      final List<TextStyle?> styles = <TextStyle?>[
        textTheme.displayLarge,
        textTheme.displayMedium,
        textTheme.displaySmall,
        textTheme.headlineLarge,
        textTheme.headlineMedium,
        textTheme.headlineSmall,
        textTheme.titleLarge,
        textTheme.titleMedium,
        textTheme.titleSmall,
        textTheme.bodyLarge,
        textTheme.bodyMedium,
        textTheme.bodySmall,
        textTheme.labelLarge,
        textTheme.labelMedium,
        textTheme.labelSmall,
      ];

      for (final TextStyle? style in styles) {
        expect(style, isNotNull);
        expect(style!.fontSize, greaterThanOrEqualTo(12.0));
      }
    });

    test('AppTheme builds Material 3 dark theme with KAYA colors', () {
      final ThemeData theme = AppTheme.darkTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
    });
  });

  group('KayaResponsive Breakpoint Boundary Calculations', () {
    test('correctly categorizes compact, medium, and expanded widths', () {
      expect(KayaResponsive.breakpointForWidth(320), KayaBreakpoint.compact);
      expect(KayaResponsive.breakpointForWidth(599.9), KayaBreakpoint.compact);
      expect(KayaResponsive.breakpointForWidth(600), KayaBreakpoint.medium);
      expect(KayaResponsive.breakpointForWidth(1023.9), KayaBreakpoint.medium);
      expect(KayaResponsive.breakpointForWidth(1024), KayaBreakpoint.expanded);
      expect(KayaResponsive.breakpointForWidth(1440), KayaBreakpoint.expanded);
    });

    test('correctly selects navigation mode and grid columns', () {
      expect(KayaResponsive.useNavigationRail(480), isFalse);
      expect(KayaResponsive.useNavigationRail(600), isTrue);
      expect(KayaResponsive.useExtendedNavigationRail(800), isFalse);
      expect(KayaResponsive.useExtendedNavigationRail(1024), isTrue);

      expect(KayaResponsive.gridColumnsForWidth(400), 1);
      expect(KayaResponsive.gridColumnsForWidth(768), 2);
      expect(KayaResponsive.gridColumnsForWidth(1280), 3);
    });
  });
}
