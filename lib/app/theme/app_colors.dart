import 'package:material_ui/material_ui.dart';

/// Centralized color tokens for the KAYA Design System.
///
/// Follows the Master Blueprint visual direction:
/// - Background: `#0D1117`
/// - Surface: `#151B23`
/// - Primary: `#6EE7B7`
/// - Secondary: `#7DD3FC`
abstract final class AppColors {
  // Core canvas & surface tokens
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF151B23);
  static const Color surfaceElevated = Color(0xFF1C2430);
  static const Color surfaceSubtle = Color(0xFF11161D);

  // Brand accent tokens
  static const Color primary = Color(0xFF6EE7B7);
  static const Color onPrimary = Color(0xFF052E1E);
  static const Color primaryContainer = Color(0xFF113529);
  static const Color onPrimaryContainer = Color(0xFFA7F3D0);

  static const Color secondary = Color(0xFF7DD3FC);
  static const Color onSecondary = Color(0xFF082A3B);
  static const Color secondaryContainer = Color(0xFF122F42);
  static const Color onSecondaryContainer = Color(0xFFBAE6FD);

  // Typography & foreground tokens (WCAG AA/AAA compliant on #0D1117 & #151B23)
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6E7681);

  // Border & divider tokens
  static const Color border = Color(0xFF26303D);
  static const Color borderSubtle = Color(0xFF1E2631);
  static const Color borderHighlight = Color(0xFF385048);

  // Semantic status tokens (always paired with icons + labels in UI)
  static const Color success = Color(0xFF34D399);
  static const Color onSuccess = Color(0xFF052E1E);
  static const Color successSurface = Color(0xFF0F2E24);

  static const Color warning = Color(0xFFFBBF24);
  static const Color onWarning = Color(0xFF332004);
  static const Color warningSurface = Color(0xFF33260D);

  static const Color error = Color(0xFFF87171);
  static const Color onError = Color(0xFF380A0A);
  static const Color errorSurface = Color(0xFF36171B);

  static const Color info = Color(0xFF7DD3FC);
  static const Color onInfo = Color(0xFF082A3B);
  static const Color infoSurface = Color(0xFF122B3B);
}
