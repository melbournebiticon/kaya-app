import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/validation/auth_validators.dart';
import 'package:kaya/features/auth/domain/auth_profile_repository.dart';
import 'package:kaya/features/auth/domain/auth_session.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/auth/domain/user_profile.dart';

class _StoredUserAccount {
  _StoredUserAccount({
    required this.userId,
    required this.email,
    required this.passwordHash,
    required this.profile,
  });

  final String userId;
  final String email;
  String passwordHash;
  UserProfile profile;
}

/// Deterministic, RLS-enforcing implementation of [AuthProfileRepository].
///
/// Mirrors the exact PostgreSQL constraints and Row Level Security policies in
/// `supabase/migrations/20261114000001_phase2_auth_and_profiles.sql`.
class InMemoryAuthProfileRepository implements AuthProfileRepository {
  InMemoryAuthProfileRepository({
    DateTime Function()? clock,
    this.sessionTtl = const Duration(hours: 24),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration sessionTtl;

  final Map<String, _StoredUserAccount> _accountsById =
      <String, _StoredUserAccount>{};
  final Map<String, String> _userIdByEmail = <String, String>{};
  final Set<String> _recoveryRequestedEmails = <String>{};

  AuthSession? _persistedSession;
  int _nextAccountSequence = 1;
  int _nextTokenSequence = 1;

  /// Optional test hook to simulate network errors and verify retry behavior.
  bool simulateNetworkFailure = false;

  /// Read-only list of emails that requested password recovery (for test verification).
  Set<String> get recoveryRequestedEmails =>
      Set<String>.unmodifiable(_recoveryRequestedEmails);

  void _checkNetwork() {
    if (simulateNetworkFailure) {
      throw AuthFailure.network();
    }
  }

  String _hashPassword(String email, String password) {
    // Deterministic non-reversible salted digest representation for local isolation.
    final String input = '${email.toLowerCase()}::$password::kaya_salt_v1';
    int hash = 0x811c9dc5;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 'h1_${hash.toRadixString(16)}_${password.length}';
  }

  AuthSession _issueSession({required String userId, required String email}) {
    final DateTime now = _clock().toUtc();
    final String token = 'kaya_tok_${_nextTokenSequence++}_$userId';
    final AuthSession session = AuthSession(
      userId: userId,
      email: email,
      accessToken: token,
      issuedAt: now,
      expiresAt: now.add(sessionTtl),
    );
    _persistedSession = session;
    return session;
  }

  /// Enforces Row Level Security (`(select auth.uid()) = id`) and active session checks.
  AuthSession _requireAuthorizedSession({String? targetUserId}) {
    final AuthSession? session = _persistedSession;
    if (session == null) {
      throw AuthFailure.unauthorizedAccess();
    }
    if (session.isExpiredAt(_clock())) {
      _persistedSession = null;
      throw AuthFailure.sessionExpired();
    }
    if (targetUserId != null && targetUserId.trim() != session.userId) {
      throw AuthFailure.unauthorizedAccess();
    }
    return session;
  }

  @override
  Future<AuthenticatedContext?> restoreSession() async {
    _checkNetwork();
    final AuthSession? session = _persistedSession;
    if (session == null) {
      return null;
    }
    if (session.isExpiredAt(_clock())) {
      _persistedSession = null;
      return null;
    }
    final _StoredUserAccount? account = _accountsById[session.userId];
    if (account == null) {
      _persistedSession = null;
      return null;
    }
    return AuthenticatedContext(session: session, profile: account.profile);
  }

  @override
  Future<AuthenticatedContext> register({
    required String email,
    required String password,
    required String displayName,
    SupportedCurrency preferredCurrency = SupportedCurrency.php,
  }) async {
    _checkNetwork();

    // Server-side validation (never trust client validation alone)
    final String? emailError = AuthValidators.validateEmail(email);
    if (emailError != null) {
      throw AuthFailure.validation(emailError);
    }
    final String? passwordError = AuthValidators.validatePassword(
      password,
      isRegistration: true,
    );
    if (passwordError != null) {
      throw AuthFailure.weakPassword();
    }
    final String? nameError = AuthValidators.validateDisplayName(displayName);
    if (nameError != null) {
      throw AuthFailure.validation(nameError);
    }

    final String normalizedEmail = email.trim().toLowerCase();
    final String normalizedName = displayName.trim();

    if (_userIdByEmail.containsKey(normalizedEmail)) {
      throw AuthFailure.emailAlreadyInUse();
    }

    final DateTime now = _clock().toUtc();
    final String userId = 'usr_${_nextAccountSequence++}';
    final UserProfile profile = UserProfile(
      userId: userId,
      email: normalizedEmail,
      displayName: normalizedName,
      preferredCurrency: preferredCurrency,
      createdAt: now,
      updatedAt: now,
    );

    final _StoredUserAccount account = _StoredUserAccount(
      userId: userId,
      email: normalizedEmail,
      passwordHash: _hashPassword(normalizedEmail, password),
      profile: profile,
    );

    _accountsById[userId] = account;
    _userIdByEmail[normalizedEmail] = userId;

    final AuthSession session = _issueSession(
      userId: userId,
      email: normalizedEmail,
    );

    return AuthenticatedContext(session: session, profile: profile);
  }

  @override
  Future<AuthenticatedContext> login({
    required String email,
    required String password,
  }) async {
    _checkNetwork();

    final String? emailError = AuthValidators.validateEmail(email);
    if (emailError != null) {
      throw AuthFailure.validation(emailError);
    }
    if (password.isEmpty) {
      throw AuthFailure.validation('Password is required.');
    }

    final String normalizedEmail = email.trim().toLowerCase();
    final String? userId = _userIdByEmail[normalizedEmail];
    if (userId == null) {
      throw AuthFailure.invalidCredentials();
    }

    final _StoredUserAccount? account = _accountsById[userId];
    if (account == null) {
      throw AuthFailure.invalidCredentials();
    }

    final String expectedHash = _hashPassword(normalizedEmail, password);
    if (account.passwordHash != expectedHash) {
      throw AuthFailure.invalidCredentials();
    }

    final AuthSession session = _issueSession(
      userId: account.userId,
      email: account.email,
    );

    return AuthenticatedContext(session: session, profile: account.profile);
  }

  @override
  Future<void> logout() async {
    _persistedSession = null;
  }

  @override
  Future<void> requestPasswordRecovery({required String email}) async {
    _checkNetwork();
    final String? emailError = AuthValidators.validateEmail(email);
    if (emailError != null) {
      throw AuthFailure.validation(emailError);
    }
    final String normalizedEmail = email.trim().toLowerCase();
    _recoveryRequestedEmails.add(normalizedEmail);
  }

  @override
  Future<UserProfile> fetchProfile({String? requestedUserId}) async {
    _checkNetwork();
    final AuthSession session = _requireAuthorizedSession(
      targetUserId: requestedUserId,
    );
    final _StoredUserAccount? account = _accountsById[session.userId];
    if (account == null) {
      throw AuthFailure.unauthorizedAccess();
    }
    return account.profile;
  }

  @override
  Future<UserProfile> updateProfile({
    String? targetUserId,
    required String displayName,
    required SupportedCurrency preferredCurrency,
  }) async {
    _checkNetwork();
    final AuthSession session = _requireAuthorizedSession(
      targetUserId: targetUserId,
    );

    final String? nameError = AuthValidators.validateDisplayName(displayName);
    if (nameError != null) {
      throw AuthFailure.validation(nameError);
    }

    final _StoredUserAccount? account = _accountsById[session.userId];
    if (account == null) {
      throw AuthFailure.unauthorizedAccess();
    }

    final UserProfile updated = account.profile.copyWith(
      displayName: displayName.trim(),
      preferredCurrency: preferredCurrency,
      updatedAt: _clock().toUtc(),
    );
    account.profile = updated;
    return updated;
  }
}
