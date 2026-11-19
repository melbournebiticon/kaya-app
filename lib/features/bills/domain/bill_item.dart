import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';

/// Immutable domain entity representing a user-owned bill in Phase 5.
///
/// Uses integer minor currency units ([amountMinor]) for centralized
/// `Safe to Spend` integration and [KayaDateOnly] for [dueDate].
class BillItem {
  const BillItem({
    required this.id,
    required this.userId,
    required this.recurrenceGroupId,
    required this.title,
    required this.notes,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.dueDate,
    required this.recurrence,
    required this.isPaid,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String recurrenceGroupId;
  final String title;
  final String notes;
  final BillCategory category;
  final int amountMinor;
  final SupportedCurrency currency;
  final KayaDateOnly dueDate;
  final BillRecurrence recurrence;
  final bool isPaid;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  BillDueBucket dueBucket(KayaDateOnly referenceToday) {
    final int cmp = dueDate.compareTo(referenceToday);
    if (cmp < 0) {
      return BillDueBucket.overdue;
    }
    if (cmp == 0) {
      return BillDueBucket.today;
    }
    return BillDueBucket.upcoming;
  }

  bool isOverdue(KayaDateOnly referenceToday) =>
      !isPaid && dueBucket(referenceToday) == BillDueBucket.overdue;

  bool isDueToday(KayaDateOnly referenceToday) =>
      !isPaid && dueBucket(referenceToday) == BillDueBucket.today;

  bool isUpcoming(KayaDateOnly referenceToday) =>
      !isPaid && dueBucket(referenceToday) == BillDueBucket.upcoming;

  String dueStatusLabel(KayaDateOnly referenceToday) {
    if (isPaid) {
      return 'Paid (${dueDate.formatReadable()})';
    }
    final int deltaDays = dueDate.daysDifferenceFrom(referenceToday);
    if (deltaDays < 0) {
      final int overdueDays = -deltaDays;
      return overdueDays == 1
          ? 'Overdue by 1 day'
          : 'Overdue by $overdueDays days';
    }
    if (deltaDays == 0) {
      return 'Due today';
    }
    if (deltaDays == 1) {
      return 'Due tomorrow';
    }
    return 'Due in $deltaDays days';
  }

  BillItem copyWith({
    String? id,
    String? userId,
    String? recurrenceGroupId,
    String? title,
    String? notes,
    BillCategory? category,
    int? amountMinor,
    SupportedCurrency? currency,
    KayaDateOnly? dueDate,
    BillRecurrence? recurrence,
    bool? isPaid,
    DateTime? paidAt,
    bool clearPaidAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BillItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recurrenceGroupId: recurrenceGroupId ?? this.recurrenceGroupId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      dueDate: dueDate ?? this.dueDate,
      recurrence: recurrence ?? this.recurrence,
      isPaid: isPaid ?? this.isPaid,
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Deterministic sorting: unpaid bills first ordered by urgency (overdue ->
  /// due today -> upcoming), then earliest dueDate, larger amount, and title.
  static int compareByUrgency(
    BillItem a,
    BillItem b,
    KayaDateOnly referenceToday,
  ) {
    if (a.isPaid != b.isPaid) {
      return a.isPaid ? 1 : -1;
    }
    final int dateCmp = a.dueDate.compareTo(b.dueDate);
    if (dateCmp != 0) {
      return dateCmp;
    }
    final int amountCmp = b.amountMinor.compareTo(a.amountMinor);
    if (amountCmp != 0) {
      return amountCmp;
    }
    final int titleCmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (titleCmp != 0) {
      return titleCmp;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BillItem &&
        other.id == id &&
        other.userId == userId &&
        other.recurrenceGroupId == recurrenceGroupId &&
        other.title == title &&
        other.notes == notes &&
        other.category == category &&
        other.amountMinor == amountMinor &&
        other.currency == currency &&
        other.dueDate == dueDate &&
        other.recurrence == recurrence &&
        other.isPaid == isPaid;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    recurrenceGroupId,
    title,
    notes,
    category,
    amountMinor,
    currency,
    dueDate,
    recurrence,
    isPaid,
  );
}
