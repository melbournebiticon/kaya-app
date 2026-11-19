import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/domain/money_enums.dart';

/// Immutable domain entity representing an actual recorded financial transaction.
///
/// Follows KAYA Section 3 & Section 5 financial rules:
/// - Stored strictly as integer minor currency units ([amountMinor]).
/// - Strictly represents actual transactions (never estimates).
/// - Uses [KayaDateOnly] for [transactionDate] to avoid timezone midnight drift.
class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.title,
    required this.notes,
    required this.amountMinor,
    required this.currency,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final TransactionType type;
  final MoneyCategory category;
  final String title;
  final String notes;
  final int amountMinor;
  final SupportedCurrency currency;
  final KayaDateOnly transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  MoneyTransaction copyWith({
    String? id,
    String? userId,
    TransactionType? type,
    MoneyCategory? category,
    String? title,
    String? notes,
    int? amountMinor,
    SupportedCurrency? currency,
    KayaDateOnly? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoneyTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Sorts transactions newest-date-first, then newest-created-first.
  static int compareByDateDesc(MoneyTransaction a, MoneyTransaction b) {
    final int dateCmp = b.transactionDate.compareTo(a.transactionDate);
    if (dateCmp != 0) {
      return dateCmp;
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MoneyTransaction &&
        other.id == id &&
        other.userId == userId &&
        other.type == type &&
        other.category == category &&
        other.title == title &&
        other.notes == notes &&
        other.amountMinor == amountMinor &&
        other.currency == currency &&
        other.transactionDate == transactionDate;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    type,
    category,
    title,
    notes,
    amountMinor,
    currency,
    transactionDate,
  );
}
