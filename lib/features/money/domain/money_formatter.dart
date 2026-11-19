import 'package:kaya/features/auth/domain/supported_currency.dart';

/// Decimal-safe currency parser and formatter backed by integer minor units.
///
/// Follows KAYA Section 3 & Section 5 financial rules:
/// - Never converts financial amounts through binary `double` arithmetic.
/// - Respects [SupportedCurrency.minorUnits] (e.g., 2 for PHP/USD, 0 for JPY).
abstract final class MoneyFormatter {
  static const int maxSupportedMinorUnits = 99999999999;

  /// Parses a user-entered monetary string into non-negative integer minor units.
  ///
  /// Returns `null` if [rawInput] is empty, negative, `NaN`, `Infinity`,
  /// scientific notation, malformed, has more decimal digits than
  /// [currency.minorUnits], or exceeds [maxSupportedMinorUnits].
  static int? tryParseMinorUnits(String rawInput, SupportedCurrency currency) {
    String sanitized = rawInput.trim();
    if (sanitized.isEmpty) {
      return null;
    }

    // Strip optional leading currency code or symbol if typed by the user.
    if (sanitized.toUpperCase().startsWith(currency.code)) {
      sanitized = sanitized.substring(currency.code.length).trim();
    }
    if (sanitized.startsWith(currency.symbol)) {
      sanitized = sanitized.substring(currency.symbol.length).trim();
    }

    sanitized = sanitized.replaceAll(',', '').trim();
    if (sanitized.isEmpty) {
      return null;
    }

    // Reject signs, scientific notation, NaN, Infinity, or extra dots.
    if (sanitized.contains('-') ||
        sanitized.contains('+') ||
        sanitized.toLowerCase().contains('e') ||
        sanitized.toLowerCase().contains('nan') ||
        sanitized.toLowerCase().contains('inf')) {
      return null;
    }

    if (currency.minorUnits == 0) {
      if (!RegExp(r'^\d+$').hasMatch(sanitized)) {
        return null;
      }
      if (sanitized.length > 12) {
        return null;
      }
      final int? parsed = int.tryParse(sanitized);
      if (parsed == null || parsed > maxSupportedMinorUnits) {
        return null;
      }
      return parsed;
    }

    final RegExp decimalPattern = RegExp(r'^(\d*)(?:\.(\d*))?$');
    final RegExpMatch? match = decimalPattern.firstMatch(sanitized);
    if (match == null) {
      return null;
    }

    final String majorPart = match.group(1) ?? '';
    final String minorPart = match.group(2) ?? '';
    if (majorPart.isEmpty && minorPart.isEmpty) {
      return null;
    }
    if (minorPart.length > currency.minorUnits) {
      return null;
    }
    if (majorPart.length > 11) {
      return null;
    }

    final int majorValue = majorPart.isEmpty ? 0 : int.parse(majorPart);
    final String paddedMinor = minorPart.padRight(currency.minorUnits, '0');
    final int minorValue = paddedMinor.isEmpty ? 0 : int.parse(paddedMinor);
    final int scale = _pow10(currency.minorUnits);
    final int totalMinor = (majorValue * scale) + minorValue;

    if (totalMinor > maxSupportedMinorUnits) {
      return null;
    }
    return totalMinor;
  }

  /// Formats integer minor units with currency symbol and thousands separators.
  static String formatMinorUnits(
    int amountMinor,
    SupportedCurrency currency, {
    bool includePlusSign = false,
  }) {
    final bool isNegative = amountMinor < 0;
    final int absMinor = amountMinor.abs();
    final String signPrefix = isNegative
        ? '-'
        : (includePlusSign && absMinor > 0 ? '+' : '');

    if (currency.minorUnits == 0) {
      final String grouped = _groupThousands(absMinor.toString());
      return '$signPrefix${currency.symbol}$grouped';
    }

    final int scale = _pow10(currency.minorUnits);
    final int major = absMinor ~/ scale;
    final int minor = absMinor % scale;
    final String groupedMajor = _groupThousands(major.toString());
    final String minorPadded = minor.toString().padLeft(
      currency.minorUnits,
      '0',
    );
    return '$signPrefix${currency.symbol}$groupedMajor.$minorPadded';
  }

  /// Formats integer minor units as plain editable text without symbols/commas.
  static String formatEditableInput(
    int amountMinor,
    SupportedCurrency currency,
  ) {
    final int absMinor = amountMinor.abs();
    if (currency.minorUnits == 0) {
      return absMinor.toString();
    }
    final int scale = _pow10(currency.minorUnits);
    final int major = absMinor ~/ scale;
    final int minor = absMinor % scale;
    if (minor == 0) {
      return major.toString();
    }
    return '$major.${minor.toString().padLeft(currency.minorUnits, '0')}';
  }

  static int _pow10(int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  static String _groupThousands(String digits) {
    if (digits.length <= 3) {
      return digits;
    }
    final StringBuffer buffer = StringBuffer();
    final int len = digits.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
