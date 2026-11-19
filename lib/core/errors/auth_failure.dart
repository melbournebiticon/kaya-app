/// Standardized error codes for authentication and authorization operations.
enum AuthFailureCode {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  validationFailed,
  sessionExpired,
  unauthorizedAccess,
  networkError,
  configurationError,
}

/// Safe, user-facing authentication or authorization error.
///
/// Never exposes raw SQL, internal database errors, or stack traces.
class AuthFailure implements Exception {
  const AuthFailure({required this.code, required this.message});

  final AuthFailureCode code;
  final String message;

  factory AuthFailure.invalidCredentials() => const AuthFailure(
    code: AuthFailureCode.invalidCredentials,
    message: 'Invalid email or password. Please check your credentials.',
  );

  factory AuthFailure.emailAlreadyInUse() => const AuthFailure(
    code: AuthFailureCode.emailAlreadyInUse,
    message: 'An account with this email address already exists.',
  );

  factory AuthFailure.weakPassword() => const AuthFailure(
    code: AuthFailureCode.weakPassword,
    message: 'Password must be at least 8 characters and include a letter and a number.',
  );

  factory AuthFailure.validation(String details) =>
      AuthFailure(code: AuthFailureCode.validationFailed, message: details);

  factory AuthFailure.sessionExpired() => const AuthFailure(
    code: AuthFailureCode.sessionExpired,
    message: 'Your session has expired. Please sign in again.',
  );

  factory AuthFailure.unauthorizedAccess() => const AuthFailure(
    code: AuthFailureCode.unauthorizedAccess,
    message: 'Access denied. You can only access your own KAYA account data.',
  );

  factory AuthFailure.network([String? safeHint]) => AuthFailure(
    code: AuthFailureCode.networkError,
    message: safeHint ?? 'Unable to reach the authentication service. Please check your connection and try again.',
  );

  factory AuthFailure.configuration(String details) =>
      AuthFailure(code: AuthFailureCode.configurationError, message: details);

  @override
  String toString() => 'AuthFailure(code: ${code.name}, message: $message)';
}
