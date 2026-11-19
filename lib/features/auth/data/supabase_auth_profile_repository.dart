import 'package:kaya/core/data/supabase_error_mapper.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/validation/auth_validators.dart';
import 'package:kaya/features/auth/domain/auth_profile_repository.dart';
import 'package:kaya/features/auth/domain/auth_session.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/auth/domain/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live Supabase implementation of [AuthProfileRepository] (Phase 2).
class SupabaseAuthProfileRepository implements AuthProfileRepository {
  SupabaseAuthProfileRepository({required this.client});

  final SupabaseClient client;

  AuthSession _mapSession(Session session) {
    final User user = session.user;
    final int? expSeconds = session.expiresAt;
    final DateTime expiresAt = expSeconds != null
        ? DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000, isUtc: true)
        : DateTime.now().toUtc().add(const Duration(hours: 1));
    return AuthSession(
      userId: user.id,
      email: (user.email ?? '').trim().toLowerCase(),
      accessToken: session.accessToken,
      issuedAt: DateTime.now().toUtc(),
      expiresAt: expiresAt,
    );
  }

  Future<UserProfile> _loadOrProvisionProfile({
    required User user,
    String? fallbackDisplayName,
    SupportedCurrency? fallbackCurrency,
  }) async {
    final Map<String, dynamic>? row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (row != null) {
      return UserProfile.fromJson(Map<String, Object?>.from(row));
    }

    final String rawEmail = (user.email ?? '').trim().toLowerCase();
    final String metaName =
        (user.userMetadata?['display_name'] as String? ?? '').trim();
    final String resolvedName =
        (fallbackDisplayName?.trim().isNotEmpty ?? false)
        ? fallbackDisplayName!.trim()
        : (metaName.isNotEmpty
              ? metaName
              : (rawEmail.contains('@')
                    ? rawEmail.split('@').first
                    : 'KAYA User'));
    final String safeName = resolvedName.length < 2
        ? 'KAYA User'
        : resolvedName;
    final String metaCurrency =
        (user.userMetadata?['preferred_currency'] as String? ?? '').trim();
    final SupportedCurrency resolvedCurrency =
        fallbackCurrency ??
        SupportedCurrency.tryFromCode(metaCurrency) ??
        SupportedCurrency.php;

    final Map<String, dynamic> inserted = await client
        .from('profiles')
        .upsert(<String, dynamic>{
          'id': user.id,
          'email': rawEmail,
          'display_name': safeName,
          'preferred_currency': resolvedCurrency.code,
        })
        .select()
        .single();
    return UserProfile.fromJson(Map<String, Object?>.from(inserted));
  }

  @override
  Future<AuthenticatedContext?> restoreSession() async {
    try {
      Session? session = client.auth.currentSession;
      if (session == null) {
        return null;
      }
      if (session.isExpired) {
        final AuthResponse refreshed = await client.auth.refreshSession();
        session = refreshed.session;
        if (session == null) {
          return null;
        }
      }
      final UserProfile profile = await _loadOrProvisionProfile(
        user: session.user,
      );
      return AuthenticatedContext(
        session: _mapSession(session),
        profile: profile,
      );
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuthException(e);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network();
    }
  }

  @override
  Future<AuthenticatedContext> register({
    required String email,
    required String password,
    required String displayName,
    SupportedCurrency preferredCurrency = SupportedCurrency.php,
  }) async {
    final String? emailErr = AuthValidators.validateEmail(email);
    if (emailErr != null) {
      throw AuthFailure.validation(emailErr);
    }
    final String? pwErr = AuthValidators.validatePassword(
      password,
      isRegistration: true,
    );
    if (pwErr != null) {
      throw AuthFailure.validation(pwErr);
    }
    final String? nameErr = AuthValidators.validateDisplayName(displayName);
    if (nameErr != null) {
      throw AuthFailure.validation(nameErr);
    }

    final String cleanEmail = email.trim().toLowerCase();
    final String cleanName = displayName.trim();

    try {
      final AuthResponse response = await client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: <String, dynamic>{
          'display_name': cleanName,
          'preferred_currency': preferredCurrency.code,
        },
      );
      final Session? session = response.session;
      final User? user = response.user;
      if (user == null) {
        throw AuthFailure.network();
      }
      if (session == null) {
        throw AuthFailure.validation(
          'Account created! Please check your email inbox to confirm your account, then sign in.',
        );
      }
      final UserProfile profile = await _loadOrProvisionProfile(
        user: user,
        fallbackDisplayName: cleanName,
        fallbackCurrency: preferredCurrency,
      );
      return AuthenticatedContext(
        session: _mapSession(session),
        profile: profile,
      );
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuthException(e);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network();
    }
  }

  @override
  Future<AuthenticatedContext> login({
    required String email,
    required String password,
  }) async {
    final String? emailErr = AuthValidators.validateEmail(email);
    if (emailErr != null) {
      throw AuthFailure.validation(emailErr);
    }
    if (password.isEmpty) {
      throw AuthFailure.validation('Password is required.');
    }

    try {
      final AuthResponse response = await client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final Session? session = response.session;
      final User? user = response.user;
      if (session == null || user == null) {
        throw AuthFailure.invalidCredentials();
      }
      final UserProfile profile = await _loadOrProvisionProfile(user: user);
      return AuthenticatedContext(
        session: _mapSession(session),
        profile: profile,
      );
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuthException(e);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network();
    }
  }

  @override
  Future<void> logout() async {
    try {
      await client.auth.signOut();
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuthException(e);
    } catch (_) {
      throw AuthFailure.network();
    }
  }

  @override
  Future<void> requestPasswordRecovery({required String email}) async {
    final String? emailErr = AuthValidators.validateEmail(email);
    if (emailErr != null) {
      throw AuthFailure.validation(emailErr);
    }
    try {
      await client.auth.resetPasswordForEmail(email.trim().toLowerCase());
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuthException(e);
    } catch (_) {
      throw AuthFailure.network();
    }
  }

  @override
  Future<UserProfile> fetchProfile({String? requestedUserId}) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      requestedOwnerId: requestedUserId,
    );
    try {
      final Map<String, dynamic> row = await client
          .from('profiles')
          .select()
          .eq('id', uid)
          .single();
      return UserProfile.fromJson(Map<String, Object?>.from(row));
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network();
    }
  }

  @override
  Future<UserProfile> updateProfile({
    String? targetUserId,
    required String displayName,
    required SupportedCurrency preferredCurrency,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      requestedOwnerId: targetUserId,
    );
    final String? nameErr = AuthValidators.validateDisplayName(displayName);
    if (nameErr != null) {
      throw AuthFailure.validation(nameErr);
    }
    try {
      final Map<String, dynamic> row = await client
          .from('profiles')
          .update(<String, dynamic>{
            'display_name': displayName.trim(),
            'preferred_currency': preferredCurrency.code,
          })
          .eq('id', uid)
          .select()
          .single();
      return UserProfile.fromJson(Map<String, Object?>.from(row));
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network();
    }
  }
}
