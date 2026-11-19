import 'package:kaya/features/auth/domain/supported_currency.dart';

/// Centralized client and domain input validators for Phase 2 Authentication
/// and User Profiles (Section 6 Input Validation Standards).
abstract final class AuthValidators {
  static const int minDisplayNameLength = 2;
  static const int maxDisplayNameLength = 60;
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int maxEmailLength = 254;

  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _hasLetter = RegExp(r'[A-Za-z]');
  static final RegExp _hasDigit = RegExp(r'[0-9]');
  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');

  /// Validates and normalizes an email address.
  /// Returns `null` if valid, or a clear user-facing error message.
  static String? validateEmail(String? rawValue) {
    final String value = (rawValue ?? '').trim();
    if (value.isEmpty) {
      return 'Email address is required.';
    }
    if (value.length > maxEmailLength) {
      return 'Email address must not exceed $maxEmailLength characters.';
    }
    if (_controlChars.hasMatch(value) || !_emailRegex.hasMatch(value)) {
      return 'Enter a valid email address (e.g. name@example.com).';
    }
    return null;
  }

  /// Validates a password for login or registration.
  static String? validatePassword(
    String? rawValue, {
    bool isRegistration = false,
  }) {
    final String value = rawValue ?? '';
    if (value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    if (value.length > maxPasswordLength) {
      return 'Password must not exceed $maxPasswordLength characters.';
    }
    if (isRegistration) {
      if (!_hasLetter.hasMatch(value) || !_hasDigit.hasMatch(value)) {
        return 'Password must contain at least one letter and one number.';
      }
    }
    return null;
  }

  /// Validates password confirmation matches the primary password.
  static String? validateConfirmPassword(String? rawConfirm, String password) {
    final String confirm = rawConfirm ?? '';
    if (confirm.isEmpty) {
      return 'Please confirm your password.';
    }
    if (confirm != password) {
      return 'Passwords do not match.';
    }
    return null;
  }

  /// Validates a user's display name after trimming leading/trailing spaces.
  static String? validateDisplayName(String? rawValue) {
    final String value = (rawValue ?? '').trim();
    if (value.isEmpty) {
      return 'Display name is required.';
    }
    if (value.length < minDisplayNameLength) {
      return 'Display name must be at least $minDisplayNameLength characters.';
    }
    if (value.length > maxDisplayNameLength) {
      return 'Display name must not exceed $maxDisplayNameLength characters.';
    }
    if (_controlChars.hasMatch(value)) {
      return 'Display name contains invalid characters.';
    }
    return null;
  }

  /// Validates that a currency code is supported by KAYA.
  static String? validateCurrencyCode(String? rawCode) {
    if (rawCode == null || rawCode.trim().isEmpty) {
      return 'Preferred currency is required.';
    }
    if (SupportedCurrency.tryFromCode(rawCode) == null) {
      return 'Unsupported currency selected.';
    }
    return null;
  }
}
