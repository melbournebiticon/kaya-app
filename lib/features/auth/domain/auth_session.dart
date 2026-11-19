/// Immutable authenticated session metadata.
///
/// Follows Section 7 Privacy & Security Standards:
/// - Redacts sensitive tokens in `toString()` so tokens are never printed in logs.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.issuedAt,
    required this.expiresAt,
  });

  final String userId;
  final String email;
  final String accessToken;
  final DateTime issuedAt;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) {
    return !now.toUtc().isBefore(expiresAt.toUtc());
  }

  @override
  String toString() {
    return 'AuthSession(userId: $userId, email: $email, token: [REDACTED], expiresAt: ${expiresAt.toIso8601String()})';
  }
}
