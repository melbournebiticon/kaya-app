import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/config/supabase_config.dart';
import 'package:kaya/core/data/supabase_error_mapper.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseConfig URL Normalization & Client Key Safety', () {
    test('normalizes /rest/v1/ and trailing slashes cleanly', () {
      const SupabaseConfig config = SupabaseConfig(
        url: ' https://fvhylpodfscbraszaxes.supabase.co/rest/v1/ ',
        anonKey: 'sb_publishable_demo_key',
      );
      expect(config.normalizedUrl, 'https://fvhylpodfscbraszaxes.supabase.co');
      expect(config.isConfigured, isTrue);
      expect(config.isClientSafeKey, isTrue);
    });

    test('rejects sb_secret_ and JWT service_role keys', () {
      const SupabaseConfig secretCfg = SupabaseConfig(
        url: 'https://demo.supabase.co',
        anonKey: 'sb_secret_should_never_pass',
      );
      expect(secretCfg.isClientSafeKey, isFalse);

      // {"role":"service_role"} -> eyJyb2xlIjoic2VydmljZV9yb2xlIn0
      const SupabaseConfig jwtServiceCfg = SupabaseConfig(
        url: 'https://demo.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.sig',
      );
      expect(jwtServiceCfg.isClientSafeKey, isFalse);
    });
  });

  group('SupabaseErrorMapper Safe Error & Date Handling', () {
    test('maps AuthException and PostgrestException codes safely', () {
      final AuthFailure invalidCreds = SupabaseErrorMapper.mapAuthException(
        const AuthException('Invalid login credentials'),
      );
      expect(invalidCreds.code, AuthFailureCode.invalidCredentials);

      final AuthFailure denied = SupabaseErrorMapper.mapPostgrestException(
        const PostgrestException(message: 'RLS violation', code: '42501'),
      );
      expect(denied.code, AuthFailureCode.unauthorizedAccess);

      final AuthFailure dup = SupabaseErrorMapper.mapPostgrestException(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      expect(dup.code, AuthFailureCode.validationFailed);
    });

    test('parses date-only ISO strings without timezone drift', () {
      expect(
        SupabaseErrorMapper.parseOptionalDateOnly('2026-11-19'),
        const KayaDateOnly(2026, 11, 19),
      );
      expect(
        SupabaseErrorMapper.parseOptionalDateOnly('2026-11-19T23:59:59Z'),
        const KayaDateOnly(2026, 11, 19),
      );
      expect(SupabaseErrorMapper.parseOptionalDateOnly(null), isNull);
    });
  });
}
