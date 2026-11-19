import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';

/// Client and repository-level input validators for Phase 5 Bills & Reminders
/// (Section 6 Input Validation Standards).
abstract final class BillReminderValidators {
  static const int minTitleLength = 1;
  static const int maxTitleLength = 120;
  static const int maxNotesLength = 500;
  static const KayaDateOnly minSupportedDate = KayaDateOnly(2000, 1, 1);
  static const KayaDateOnly maxSupportedDate = KayaDateOnly(2100, 12, 31);

  static final RegExp _disallowedControlChars = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

  /// Validates a bill or reminder title after trimming leading/trailing spaces.
  static String? validateTitle(String? rawTitle, {String fieldName = 'Title'}) {
    final String trimmed = (rawTitle ?? '').trim();
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

  /// Validates optional bill or reminder notes.
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

  /// Validates a required due date within supported calendar bounds.
  static String? validateDueDate(
    KayaDateOnly? dueDate, {
    String fieldName = 'Due date',
  }) {
    if (dueDate == null) {
      return '$fieldName is required.';
    }
    if (dueDate.isBefore(minSupportedDate) ||
        dueDate.isAfter(maxSupportedDate)) {
      return '$fieldName must be between 2000-01-01 and 2100-12-31.';
    }
    return null;
  }

  /// Validates a positive user-entered bill amount in [currency].
  static String? validateBillAmountInput(
    String? rawInput,
    SupportedCurrency currency,
  ) {
    return MoneyValidators.validatePositiveAmountInput(
      rawInput,
      currency,
      fieldName: 'Bill amount',
    );
  }

  /// Validates positive bill amount minor units at repository/server boundary.
  static String? validateBillAmountMinor(int? amountMinor) {
    return MoneyValidators.validatePositiveMinorUnits(
      amountMinor,
      fieldName: 'Bill amount',
    );
  }
}
