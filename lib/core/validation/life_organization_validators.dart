import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';

/// Client and repository-level input validators for Phase 7 Life Organization:
/// Smart Checklists, Daily Routines, and Shopping Lists.
abstract final class LifeOrganizationValidators {
  static const int minTitleLength = 1;
  static const int maxTitleLength = 120;
  static const int minQuantity = 1;
  static const int maxQuantity = 9999;

  static final RegExp _disallowedControlChars = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

  /// Validates checklist, routine, step, shopping list, or product names.
  static String? validateTitle(String? raw, {required String fieldName}) {
    final String trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return '$fieldName is required.';
    }
    if (trimmed.length < minTitleLength) {
      return '$fieldName must be at least $minTitleLength character.';
    }
    if (trimmed.length > maxTitleLength) {
      return '$fieldName must not exceed $maxTitleLength characters.';
    }
    if (_disallowedControlChars.hasMatch(trimmed)) {
      return '$fieldName contains invalid characters.';
    }
    return null;
  }

  /// Validates scheduled ISO weekdays (`1..7`) for daily routines.
  static String? validateScheduledWeekdays(Set<int>? weekdays) {
    if (weekdays == null || weekdays.isEmpty) {
      return 'Select at least one scheduled day.';
    }
    for (final int day in weekdays) {
      if (day < 1 || day > 7) {
        return 'Scheduled weekdays must be between Monday (1) and Sunday (7).';
      }
    }
    return null;
  }

  /// Validates integer item quantity (`1..9999`).
  static String? validateQuantityInput(String? raw) {
    final String trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Quantity is required.';
    }
    final int? parsed = int.tryParse(trimmed);
    return validateQuantity(parsed);
  }

  static String? validateQuantity(int? quantity) {
    if (quantity == null) {
      return 'Enter a whole number quantity.';
    }
    if (quantity < minQuantity || quantity > maxQuantity) {
      return 'Quantity must be between $minQuantity and $maxQuantity.';
    }
    return null;
  }

  /// Validates estimated shopping unit price (allows `0` or positive minor
  /// units without mixing NaN/Infinity/negative values).
  static String? validateEstimatedPriceInput(
    String? raw,
    SupportedCurrency currency,
  ) {
    final String trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Estimated price is required (enter 0 if unknown).';
    }
    if (trimmed.contains('-')) {
      return 'Estimated price cannot be negative.';
    }
    final String lower = trimmed.toLowerCase();
    if (lower.contains('nan') || lower.contains('inf')) {
      return 'Enter a valid numeric estimated price.';
    }
    if (currency.minorUnits == 0 && trimmed.contains('.')) {
      return '${currency.code} prices must be whole numbers.';
    }
    final int? minor = MoneyFormatter.tryParseMinorUnits(trimmed, currency);
    if (minor == null) {
      return currency.minorUnits == 0
          ? 'Enter a valid whole ${currency.code} price.'
          : 'Enter a valid price with up to ${currency.minorUnits} decimal places.';
    }
    if (minor < 0 || minor > MoneyValidators.maxAmountMinor) {
      return 'Estimated price exceeds supported limits.';
    }
    return null;
  }
}
