import 'package:material_ui/material_ui.dart';

/// Centralized spacing, border radius, and layout constraint tokens for KAYA.
abstract final class AppSpacing {
  // 4pt / 8pt spacing scale
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Border radius tokens
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusPill = 999.0;

  // Accessibility & layout constraints
  static const double minTouchTarget = 48.0;
  static const double maxContentWidth = 1120.0;
  static const double maxFormWidth = 560.0;

  // Common padding presets
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(lg);
  static const EdgeInsets pagePaddingCompact = EdgeInsets.symmetric(
    horizontal: md,
    vertical: md,
  );
  static const EdgeInsets pagePaddingMedium = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: lg,
  );
  static const EdgeInsets pagePaddingExpanded = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: lg,
  );
}
