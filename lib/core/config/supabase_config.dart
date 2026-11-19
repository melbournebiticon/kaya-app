import 'dart:convert';

/// Runtime configuration for Supabase connectivity.
///
/// Follows Section 7 Security Standards:
/// - Never hardcode credentials in source control.
/// - Reject `service_role` keys in client builds (fail closed).
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  final String url;
  final String anonKey;

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Loads configuration from `--dart-define=SUPABASE_URL=...` and
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  factory SupabaseConfig.fromEnvironment() {
    return const SupabaseConfig(url: _envUrl, anonKey: _envAnonKey);
  }

  /// Normalizes [url] by trimming trailing slashes and accidental `/rest/v1`
  /// suffixes copied from the Supabase API dashboard.
  String get normalizedUrl {
    String clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.toLowerCase().endsWith('/rest/v1')) {
      clean = clean.substring(0, clean.length - '/rest/v1'.length);
    }
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  /// Whether live Supabase environment variables were supplied at build/run time.
  bool get isConfigured =>
      normalizedUrl.isNotEmpty && anonKey.trim().isNotEmpty;

  /// Validates that the configured key is safe for client usage and is NEVER a
  /// privileged `service_role` key.
  bool get isClientSafeKey {
    final String trimmed = anonKey.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.toLowerCase().contains('service_role') ||
        trimmed.startsWith('sb_secret_')) {
      return false;
    }

    // Inspect JWT payload if key is a 3-part JWT.
    final List<String> parts = trimmed.split('.');
    if (parts.length == 3) {
      try {
        final String normalized = base64Url.normalize(parts[1]);
        final String payloadJson = utf8.decode(base64Url.decode(normalized));
        final Object? decoded = jsonDecode(payloadJson);
        if (decoded is Map<String, Object?>) {
          final Object? role = decoded['role'];
          if (role == 'service_role') {
            return false;
          }
        }
      } catch (_) {
        // Non-JWT publishable token; permitted if not service_role/sb_secret_.
      }
    }
    return true;
  }
}
