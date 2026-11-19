import 'package:kaya/features/auth/domain/supported_currency.dart';

/// Immutable user profile entity owned strictly by `userId`.
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.preferredCurrency,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String email;
  final String displayName;
  final SupportedCurrency preferredCurrency;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get initials {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'K';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  UserProfile copyWith({
    String? displayName,
    SupportedCurrency? preferredCurrency,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId,
      email: email,
      displayName: displayName ?? this.displayName,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': userId,
      'email': email,
      'display_name': displayName,
      'preferred_currency': preferredCurrency.code,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, Object?> json) {
    final String id = (json['id'] as String? ?? '').trim();
    final String email = (json['email'] as String? ?? '').trim().toLowerCase();
    final String displayName = (json['display_name'] as String? ?? '').trim();
    final String currencyCode = (json['preferred_currency'] as String? ?? 'PHP')
        .trim();
    final SupportedCurrency currency =
        SupportedCurrency.tryFromCode(currencyCode) ?? SupportedCurrency.php;

    final DateTime createdAt =
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final DateTime updatedAt =
        DateTime.tryParse(json['updated_at'] as String? ?? '')?.toUtc() ??
        createdAt;

    return UserProfile(
      userId: id,
      email: email,
      displayName: displayName,
      preferredCurrency: currency,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is UserProfile &&
        other.userId == userId &&
        other.email == email &&
        other.displayName == displayName &&
        other.preferredCurrency == preferredCurrency &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    userId,
    email,
    displayName,
    preferredCurrency,
    createdAt,
    updatedAt,
  );
}
