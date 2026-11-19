import 'package:kaya/core/utils/kaya_date_only.dart';

/// Client and repository-level input validators for Phase 6 Life Vault
/// (Section 6 Input Validation & Privacy Standards).
abstract final class LifeVaultValidators {
  static const int minTextLength = 1;
  static const int maxTextLength = 120;
  static const int maxNotesLength = 500;

  static const KayaDateOnly minDocumentDate = KayaDateOnly(1950, 1, 1);
  static const KayaDateOnly maxDocumentDate = KayaDateOnly(2100, 12, 31);
  static const KayaDateOnly minReturnDate = KayaDateOnly(2000, 1, 1);
  static const KayaDateOnly maxReturnDate = KayaDateOnly(2100, 12, 31);

  static final RegExp _disallowedControlChars = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

  /// Validates required names, titles, and storage locations.
  static String? validateRequiredText(
    String? raw, {
    required String fieldName,
  }) {
    final String trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return '$fieldName is required.';
    }
    if (trimmed.length < minTextLength) {
      return '$fieldName must be at least $minTextLength character.';
    }
    if (trimmed.length > maxTextLength) {
      return '$fieldName must not exceed $maxTextLength characters.';
    }
    if (_disallowedControlChars.hasMatch(trimmed)) {
      return '$fieldName contains invalid characters.';
    }
    return null;
  }

  /// Validates optional Life Vault notes.
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

  /// Validates document issue and expiration date bounds and ordering
  /// (`expirationDate >= issueDate` when both are provided).
  static String? validateDocumentDates({
    KayaDateOnly? issueDate,
    KayaDateOnly? expirationDate,
  }) {
    if (issueDate != null &&
        (issueDate.isBefore(minDocumentDate) ||
            issueDate.isAfter(maxDocumentDate))) {
      return 'Issue date must be between 1950-01-01 and 2100-12-31.';
    }
    if (expirationDate != null &&
        (expirationDate.isBefore(minDocumentDate) ||
            expirationDate.isAfter(maxDocumentDate))) {
      return 'Expiration date must be between 1950-01-01 and 2100-12-31.';
    }
    if (issueDate != null &&
        expirationDate != null &&
        expirationDate.isBefore(issueDate)) {
      return 'Expiration date cannot be earlier than the issue date.';
    }
    return null;
  }

  /// Validates counterparty person/entity when an item is lent out or borrowed.
  static String? validateCounterparty({
    required bool requiresCounterparty,
    String? counterpartyName,
  }) {
    final String trimmed = (counterpartyName ?? '').trim();
    if (!requiresCounterparty) {
      if (trimmed.length > maxTextLength) {
        return 'Person/entity name must not exceed $maxTextLength characters.';
      }
      return null;
    }
    if (trimmed.isEmpty) {
      return 'Person or borrower/lender name is required.';
    }
    if (trimmed.length > maxTextLength) {
      return 'Person or borrower/lender name must not exceed $maxTextLength characters.';
    }
    if (_disallowedControlChars.hasMatch(trimmed)) {
      return 'Person or borrower/lender name contains invalid characters.';
    }
    return null;
  }

  /// Validates an optional due return date for lent/borrowed items.
  static String? validateDueReturnDate(KayaDateOnly? dueReturnDate) {
    if (dueReturnDate == null) {
      return null;
    }
    if (dueReturnDate.isBefore(minReturnDate) ||
        dueReturnDate.isAfter(maxReturnDate)) {
      return 'Return date must be between 2000-01-01 and 2100-12-31.';
    }
    return null;
  }
}
