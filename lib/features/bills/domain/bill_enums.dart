import 'package:kaya/core/utils/kaya_date_only.dart';

/// Categories for user bills matching PostgreSQL CHECK constraints.
enum BillCategory {
  utilities(dbValue: 'utilities', label: 'Utilities (Power & Water)'),
  housing(dbValue: 'housing', label: 'Housing & Rent'),
  internetPhone(dbValue: 'internet_phone', label: 'Internet & Mobile'),
  insurance(dbValue: 'insurance', label: 'Insurance'),
  subscriptions(dbValue: 'subscriptions', label: 'Subscriptions & Plans'),
  creditDebt(dbValue: 'credit_debt', label: 'Credit Card & Loans'),
  taxesGov(dbValue: 'taxes_gov', label: 'Taxes & Contributions'),
  other(dbValue: 'other', label: 'Other Bills');

  const BillCategory({required this.dbValue, required this.label});

  final String dbValue;
  final String label;

  static BillCategory? tryFromDbValue(String? raw) {
    if (raw == null) {
      return null;
    }
    final String normalized = raw.trim().toLowerCase();
    for (final BillCategory value in BillCategory.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// Supported recurrence cadences for recurring bills.
enum BillRecurrence {
  oneTime(dbValue: 'one_time', label: 'One-time'),
  monthly(dbValue: 'monthly', label: 'Monthly'),
  yearly(dbValue: 'yearly', label: 'Yearly');

  const BillRecurrence({required this.dbValue, required this.label});

  final String dbValue;
  final String label;

  /// Computes the next cycle's calendar due date with month-end clamping,
  /// or `null` for [oneTime] bills.
  KayaDateOnly? nextDueDate(KayaDateOnly currentDueDate) {
    return switch (this) {
      BillRecurrence.oneTime => null,
      BillRecurrence.monthly => currentDueDate.addMonths(1),
      BillRecurrence.yearly => currentDueDate.addYears(1),
    };
  }

  static BillRecurrence? tryFromDbValue(String? raw) {
    if (raw == null) {
      return null;
    }
    final String normalized = raw.trim().toLowerCase();
    for (final BillRecurrence value in BillRecurrence.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// Relative calendar due-date classification for unpaid bills.
enum BillDueBucket { overdue, today, upcoming }

/// Filter views supported in the Bills workspace.
enum BillFilterView {
  unpaid(label: 'Unpaid'),
  overdue(label: 'Overdue'),
  upcoming(label: 'Upcoming'),
  paid(label: 'Paid'),
  all(label: 'All');

  const BillFilterView({required this.label});

  final String label;
}
