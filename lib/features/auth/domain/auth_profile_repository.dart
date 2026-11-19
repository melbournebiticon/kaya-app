import 'package:kaya/features/auth/domain/auth_session.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/auth/domain/user_profile.dart';

/// Result tuple returned when a user authenticates or restores a session.
class AuthenticatedContext {
  const AuthenticatedContext({required this.session, required this.profile});

  final AuthSession session;
  final UserProfile profile;
}

/// Abstract repository contract for Phase 2 Authentication & User Profiles.
///
/// Enforces server-side validation and Row-Level Ownership isolation.
abstract class AuthProfileRepository {
  /// Restores a previously persisted session if valid and non-expired.
  Future<AuthenticatedContext?> restoreSession();

  /// Registers a new user account and provisions their initial [UserProfile].
  Future<AuthenticatedContext> register({
    required String email,
    required String password,
    required String displayName,
    SupportedCurrency preferredCurrency = SupportedCurrency.php,
  });

  /// Authenticates an existing user and loads only their own [UserProfile].
  Future<AuthenticatedContext> login({
    required String email,
    required String password,
  });

  /// Signs out the current user and invalidates the active session.
  Future<void> logout();

  /// Initiates a password recovery email/flow for [email].
  Future<void> requestPasswordRecovery({required String email});

  /// Fetches a user profile, enforcing RLS (`auth.uid() == requestedUserId`).
  Future<UserProfile> fetchProfile({String? requestedUserId});

  /// Updates a user profile, enforcing RLS (`auth.uid() == targetUserId`).
  Future<UserProfile> updateProfile({
    String? targetUserId,
    required String displayName,
    required SupportedCurrency preferredCurrency,
  });
}
