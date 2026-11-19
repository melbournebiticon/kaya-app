import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/config/supabase_config.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/validation/auth_validators.dart';
import 'package:kaya/features/auth/application/auth_controller.dart';
import 'package:kaya/features/auth/data/in_memory_auth_profile_repository.dart';
import 'package:kaya/features/auth/domain/auth_profile_repository.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';

String _buildFakeJwtWithRole(String role) {
  final String header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
  final String payload = base64Url.encode(utf8.encode('{"role":"$role"}'));
  return '$header.$payload.signature';
}

void main() {
  group('Phase 2 Input Validation & Boundary Tests (Section 6)', () {
    test('validateEmail enforces required, format, whitespace, and length', () {
      expect(AuthValidators.validateEmail(null), isNotNull);
      expect(AuthValidators.validateEmail('   '), isNotNull);
      expect(AuthValidators.validateEmail('not-an-email'), isNotNull);
      expect(AuthValidators.validateEmail('user@domain'), isNotNull);

      final String tooLong = '${'a' * 245}@example.com';
      expect(AuthValidators.validateEmail(tooLong), isNotNull);

      expect(AuthValidators.validateEmail('  valid.user@kaya.app '), isNull);
    });

    test('validatePassword enforces boundary lengths and complexity', () {
      expect(AuthValidators.validatePassword(''), isNotNull);
      // Boundary: 7 chars rejected, 8 chars accepted
      expect(AuthValidators.validatePassword('Abcdef1'), isNotNull);
      expect(AuthValidators.validatePassword('Abcdefg1'), isNull);

      // Registration complexity: requires both letter and digit
      expect(
        AuthValidators.validatePassword('onlyletters', isRegistration: true),
        isNotNull,
      );
      expect(
        AuthValidators.validatePassword('123456789', isRegistration: true),
        isNotNull,
      );
      expect(
        AuthValidators.validatePassword('SecurePass1', isRegistration: true),
        isNull,
      );

      // Boundary: 129 chars rejected
      expect(AuthValidators.validatePassword('A1${'a' * 127}'), isNotNull);
    });

    test('validateDisplayName enforces trimmed 2..60 character boundaries', () {
      expect(AuthValidators.validateDisplayName(''), isNotNull);
      expect(AuthValidators.validateDisplayName('  A  '), isNotNull);
      expect(AuthValidators.validateDisplayName('Al'), isNull);
      expect(AuthValidators.validateDisplayName('A' * 60), isNull);
      expect(AuthValidators.validateDisplayName('A' * 61), isNotNull);
    });

    test('validateCurrencyCode accepts only supported currencies', () {
      expect(AuthValidators.validateCurrencyCode(null), isNotNull);
      expect(AuthValidators.validateCurrencyCode('XYZ'), isNotNull);
      expect(AuthValidators.validateCurrencyCode('php'), isNull);
      expect(AuthValidators.validateCurrencyCode('USD'), isNull);
    });
  });

  group('Phase 2 Security, RLS Isolation & Session Lifecycle (Section 7)', () {
    test(
      'SupabaseConfig rejects service_role and secret keys (fails closed)',
      () {
        final SupabaseConfig serviceRoleJwt = SupabaseConfig(
          url: 'https://project.supabase.co',
          anonKey: _buildFakeJwtWithRole('service_role'),
        );
        expect(serviceRoleJwt.isClientSafeKey, isFalse);

        const SupabaseConfig sbSecret = SupabaseConfig(
          url: 'https://project.supabase.co',
          anonKey: 'sb_secret_123456789',
        );
        expect(sbSecret.isClientSafeKey, isFalse);

        final SupabaseConfig anonJwt = SupabaseConfig(
          url: 'https://project.supabase.co',
          anonKey: _buildFakeJwtWithRole('anon'),
        );
        expect(anonJwt.isClientSafeKey, isTrue);
      },
    );

    test('Cross-account RLS isolation: User B cannot read or update User A profile', () async {
      final InMemoryAuthProfileRepository repo =
          InMemoryAuthProfileRepository();

      // 1. Register User A (Alice)
      final AuthenticatedContext aliceCtx = await repo.register(
        email: 'alice@kaya.app',
        password: 'Password123',
        displayName: 'Alice Santos',
        preferredCurrency: SupportedCurrency.php,
      );
      final String aliceId = aliceCtx.profile.userId;

      // 2. Register User B (Bob) - active session switches to Bob
      final AuthenticatedContext bobCtx = await repo.register(
        email: 'bob@kaya.app',
        password: 'Password456',
        displayName: 'Bob Cruz',
        preferredCurrency: SupportedCurrency.usd,
      );
      expect(bobCtx.profile.userId, isNot(equals(aliceId)));

      // 3. Bob attempting to read Alice's profile must be denied by RLS check
      await expectLater(
        () => repo.fetchProfile(requestedUserId: aliceId),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure f) => f.code,
            'code',
            AuthFailureCode.unauthorizedAccess,
          ),
        ),
      );

      // 4. Bob attempting to update Alice's profile must be denied by RLS check
      await expectLater(
        () => repo.updateProfile(
          targetUserId: aliceId,
          displayName: 'Hacked Name',
          preferredCurrency: SupportedCurrency.eur,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure f) => f.code,
            'code',
            AuthFailureCode.unauthorizedAccess,
          ),
        ),
      );

      // 5. Verify Alice's record was untouched when Alice logs back in
      final AuthenticatedContext aliceRelogin = await repo.login(
        email: 'alice@kaya.app',
        password: 'Password123',
      );
      expect(aliceRelogin.profile.displayName, 'Alice Santos');
      expect(aliceRelogin.profile.preferredCurrency, SupportedCurrency.php);
    });

    test('Session restoration, expiration, token redaction, and logout cache clearing', () async {
      DateTime currentTime = DateTime.utc(2026, 11, 14, 10, 0);
      final InMemoryAuthProfileRepository repo = InMemoryAuthProfileRepository(
        clock: () => currentTime,
        sessionTtl: const Duration(hours: 2),
      );
      final AuthController controller = AuthController(repository: repo);

      final bool registered = await controller.register(
        email: 'user@kaya.app',
        password: 'Password123',
        displayName: 'Marco Reyes',
        preferredCurrency: SupportedCurrency.sgd,
      );
      expect(registered, isTrue);
      expect(controller.isAuthenticated, isTrue);

      // Verify token is redacted in toString() logs
      final String sessionString = controller.session.toString();
      expect(sessionString, contains('[REDACTED]'));
      expect(sessionString, isNot(contains(controller.session!.accessToken)));

      // Advance clock by 1 hour (still valid) and restore session
      currentTime = currentTime.add(const Duration(hours: 1));
      await controller.restoreSession();
      expect(controller.isAuthenticated, isTrue);
      expect(controller.profile?.displayName, 'Marco Reyes');

      // Advance clock past 2-hour TTL -> session expires
      currentTime = currentTime.add(const Duration(hours: 2));
      await controller.restoreSession();
      expect(controller.isAuthenticated, isFalse);
      expect(controller.profile, isNull);

      // Re-login and then logout -> private state wiped immediately
      await controller.login(email: 'user@kaya.app', password: 'Password123');
      expect(controller.isAuthenticated, isTrue);

      await controller.logout();
      expect(controller.isAuthenticated, isFalse);
      expect(controller.profile, isNull);
      expect(controller.session, isNull);
    });
  });
}
