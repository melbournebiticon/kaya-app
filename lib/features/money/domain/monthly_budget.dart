import 'package:kaya/features/auth/domain/supported_currency.dart';

/// Immutable domain entity representing a user's monthly spending budget.
class MonthlyBudget {
  const MonthlyBudget({
    required this.id,
    required this.userId,
    required this.year,
    required this.month,
    required this.currency,
    required this.overallLimitMinor,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final int year;
  final int month;
  final SupportedCurrency currency;
  final int overallLimitMinor;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get periodKey =>
      '$year-${month.toString().padLeft(2, '0')}-${currency.code}';

  MonthlyBudget copyWith({
    String? id,
    String? userId,
    int? year,
    int? month,
    SupportedCurrency? currency,
    int? overallLimitMinor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlyBudget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      year: year ?? this.year,
      month: month ?? this.month,
      currency: currency ?? this.currency,
      overallLimitMinor: overallLimitMinor ?? this.overallLimitMinor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MonthlyBudget &&
        other.id == id &&
        other.userId == userId &&
        other.year == year &&
        other.month == month &&
        other.currency == currency &&
        other.overallLimitMinor == overallLimitMinor;
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, year, month, currency, overallLimitMinor);
}
