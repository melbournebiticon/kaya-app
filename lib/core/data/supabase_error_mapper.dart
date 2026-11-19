import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared authorization checks, safe error mapping, and row parsing helpers
/// for Supabase repositories.
abstract final class SupabaseErrorMapper {
  /// Verifies an authenticated Supabase session exists and matches any
  /// caller-supplied [expectedUserId] or [requestedOwnerId].
  static String requireAuthenticatedUserId(
    SupabaseClient client, {
    String? expectedUserId,
    String? requestedOwnerId,
  }) {
    final String? uid = client.auth.currentUser?.id;
    if (uid == null || uid.trim().isEmpty) {
      throw AuthFailure.sessionExpired();
    }
    if (expectedUserId != null && expectedUserId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    if (requestedOwnerId != null &&
        requestedOwnerId.trim().isNotEmpty &&
        requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return uid;
  }

  /// Maps Supabase Auth errors into safe, user-facing [AuthFailure] instances.
  static AuthFailure mapAuthException(AuthException error) {
    final String msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password')) {
      return AuthFailure.invalidCredentials();
    }
    if (msg.contains('already registered') ||
        msg.contains('already exists') ||
        msg.contains('user already')) {
      return AuthFailure.emailAlreadyInUse();
    }
    if (msg.contains('email not confirmed')) {
      return AuthFailure.validation(
        'Please confirm your email address from your inbox before signing in.',
      );
    }
    if (msg.contains('password')) {
      return AuthFailure.weakPassword();
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return AuthFailure.network(
        'Too many attempts right now. Please wait a moment and try again.',
      );
    }
    return AuthFailure.network();
  }

  /// Maps PostgreSQL / PostgREST errors without exposing raw SQL or internals.
  static AuthFailure mapPostgrestException(
    PostgrestException error, {
    String? fallbackMessage,
  }) {
    final String code = (error.code ?? '').trim().toUpperCase();
    if (code == '42501' || code == 'PGRST116') {
      return AuthFailure.unauthorizedAccess();
    }
    if (code == '23505') {
      return AuthFailure.validation('A matching record already exists.');
    }
    if (code == '23514' || code == '22P02') {
      return AuthFailure.validation(
        'Please verify your input values and try again.',
      );
    }
    return AuthFailure.network(
      fallbackMessage ?? 'Unable to sync with KAYA server. Please check your connection and try again.',
    );
  }

  static DateTime parseDateTimeUtc(Object? raw, {DateTime? fallback}) {
    if (raw is DateTime) {
      return raw.toUtc();
    }
    if (raw is String) {
      final DateTime? parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    return (fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
        .toUtc();
  }

  static DateTime? parseOptionalDateTimeUtc(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw.toUtc();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc();
    }
    return null;
  }

  static int parseInt(Object? raw, {int fallback = 0}) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw.trim()) ?? fallback;
    }
    return fallback;
  }

  static KayaDateOnly? parseOptionalDateOnly(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return KayaDateOnly(raw.year, raw.month, raw.day);
    }
    final String text = raw.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    final String datePart = text.length >= 10 ? text.substring(0, 10) : text;
    return KayaDateOnly.tryParse(datePart);
  }

  static KayaDateOnly parseDateOnly(Object? raw) {
    final KayaDateOnly? parsed = parseOptionalDateOnly(raw);
    if (parsed == null) {
      throw AuthFailure.network(
        'Received an invalid calendar date from server.',
      );
    }
    return parsed;
  }
}
