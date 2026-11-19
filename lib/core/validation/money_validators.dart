import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';

/// Client and repository-level input validators for Phase 4 Money Management
/// (Section 6 Input Validation Standards).
abstract final class MoneyValidators {
  static const int minTitleLength = 1;
  static const int maxTitleLength = 120;
  static const int maxNotesLength = 500;
  static const int maxAmountMinor = MoneyFormatter.maxSupportedMinorUnits;
  static const KayaDateOnly minSupportedDate = KayaDateOnly(2000, 1, 1);
  static const KayaDateOnly maxSupportedDate = KayaDateOnly(2100, 12, 31);

  static final RegExp _disallowedControlChars = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

  /// Validates a transaction title or label.
  static String? validateTitle(String? rawTitle) {
    final String trimmed = (rawTitle ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Description is required.';
    }
    if (trimmed.length < minTitleLength) {
      return 'Description must be at least $minTitleLength character.';
    }
    if (trimmed.length > maxTitleLength) {
      return 'Description must not exceed $maxTitleLength characters.';
    }
    if (_disallowedControlChars.hasMatch(trimmed)) {
      return 'Description contains invalid characters.';
    }
    return null;
  }

  /// Validates optional transaction notes.
  static String? validateNotes(String? rawNotes) {
    final String trimmed = (rawNotes ?? '').trim();
    if (trimmed.length > maxNotesLength) {
      return 'Notes must not exceed $maxNotesLength characters.';
    }
    if (_disallowedControlChars.hasMatch(trimmed)) {
      return 'Notes contain invalid control characters.';
    }
    return null;
  }

  /// Validates a user-entered monetary string for a strictly positive amount.
  static String? validatePositiveAmountInput(
    String? rawInput,
    SupportedCurrency currency, {
    String fieldName = 'Amount',
  }) {
    final String trimmed = (rawInput ?? '').trim();
    if (trimmed.isEmpty) {
      return '$fieldName is required.';
    }
    if (trimmed.contains('-')) {
      return '$fieldName cannot be negative.';
    }
    final String lower = trimmed.toLowerCase();
    if (lower.contains('nan') || lower.contains('inf')) {
      return 'Enter a valid numeric $fieldName.';
    }
    if (currency.minorUnits == 0 && trimmed.contains('.')) {
      return '${currency.code} amounts must be whole numbers without decimals.';
    }

    final int? parsedMinor = MoneyFormatter.tryParseMinorUnits(
      trimmed,
      currency,
    );
    if (parsedMinor == null) {
      return currency.minorUnits == 0
          ? 'Enter a valid whole ${currency.code} amount.'
          : 'Enter a valid amount with up to ${currency.minorUnits} decimal places.';
    }
    return validatePositiveMinorUnits(parsedMinor, fieldName: fieldName);
  }

  /// Validates integer minor units at repository/server boundary.
  static String? validatePositiveMinorUnits(
    int? amountMinor, {
    String fieldName = 'Amount',
  }) {
    if (amountMinor == null) {
      return '$fieldName is required.';
    }
    if (amountMinor <= 0) {
      return '$fieldName must be greater than zero.';
    }
    if (amountMinor > maxAmountMinor) {
      return '$fieldName exceeds the maximum supported limit.';
    }
    return null;
  }

  /// Validates that transaction date is non-null and within supported bounds.
  static String? validateTransactionDate(KayaDateOnly? date) {
    if (date == null) {
      return 'Transaction date is required.';
    }
    if (date.isBefore(minSupportedDate) || date.isAfter(maxSupportedDate)) {
      return 'Transaction date must be between 2000-01-01 and 2100-12-31.';
    }
    return null;
  }
}
