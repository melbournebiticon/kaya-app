import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_repository.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:kaya/features/money/domain/monthly_budget.dart';

/// Deterministic, RLS-enforcing implementation of [MoneyRepository].
///
/// Mirrors the server-side constraints and Row Level Security policies in
/// `supabase/migrations/20261114000003_phase4_money.sql`.
class InMemoryMoneyRepository implements MoneyRepository {
  InMemoryMoneyRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, MoneyTransaction> _transactionsById =
      <String, MoneyTransaction>{};
  final Map<String, MonthlyBudget> _budgetsById = <String, MonthlyBudget>{};
  int _nextTransactionSeq = 1;
  int _nextBudgetSeq = 1;

  /// Test hook to simulate network errors and verify error/retry states.
  bool simulateNetworkFailure = false;

  void _checkNetwork() {
    if (simulateNetworkFailure) {
      throw AuthFailure.network(
        'Unable to synchronize financial records. Please check your connection and try again.',
      );
    }
  }

  String _requireAuthenticatedUser(String authenticatedUserId) {
    final String trimmed = authenticatedUserId.trim();
    if (trimmed.isEmpty) {
      throw AuthFailure.unauthorizedAccess();
    }
    return trimmed;
  }

  MoneyTransaction _requireOwnedTransaction({
    required String authenticatedUserId,
    required String transactionId,
  }) {
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final MoneyTransaction? existing = _transactionsById[transactionId.trim()];
    if (existing == null || existing.userId != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return existing;
  }

  void _validateTransactionPayload({
    required TransactionType type,
    required MoneyCategory category,
    required String title,
    required String notes,
    required int amountMinor,
    required KayaDateOnly transactionDate,
  }) {
    if (category.transactionType != type) {
      throw AuthFailure.validation(
        'Category "${category.label}" does not match ${type.label}.',
      );
    }
    final String? titleError = MoneyValidators.validateTitle(title);
    if (titleError != null) {
      throw AuthFailure.validation(titleError);
    }
    final String? notesError = MoneyValidators.validateNotes(notes);
    if (notesError != null) {
      throw AuthFailure.validation(notesError);
    }
    final String? amountError = MoneyValidators.validatePositiveMinorUnits(
      amountMinor,
    );
    if (amountError != null) {
      throw AuthFailure.validation(amountError);
    }
    final String? dateError = MoneyValidators.validateTransactionDate(
      transactionDate,
    );
    if (dateError != null) {
      throw AuthFailure.validation(dateError);
    }
  }

  @override
  Future<List<MoneyTransaction>> fetchTransactions({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }

    return _transactionsById.values
        .where((MoneyTransaction tx) => tx.userId == uid)
        .toList();
  }

  @override
  Future<MoneyTransaction> createTransaction({
    required String authenticatedUserId,
    required TransactionType type,
    required MoneyCategory category,
    required String title,
    String notes = '',
    required int amountMinor,
    required SupportedCurrency currency,
    required KayaDateOnly transactionDate,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    _validateTransactionPayload(
      type: type,
      category: category,
      title: title,
      notes: notes,
      amountMinor: amountMinor,
      transactionDate: transactionDate,
    );

    final DateTime now = _clock().toUtc();
    final String id = 'mtx_${_nextTransactionSeq++}';
    final MoneyTransaction created = MoneyTransaction(
      id: id,
      userId: uid,
      type: type,
      category: category,
      title: title.trim(),
      notes: notes.trim(),
      amountMinor: amountMinor,
      currency: currency,
      transactionDate: transactionDate,
      createdAt: now,
      updatedAt: now,
    );
    _transactionsById[id] = created;
    return created;
  }

  @override
  Future<MoneyTransaction> updateTransaction({
    required String authenticatedUserId,
    required String transactionId,
    required TransactionType type,
    required MoneyCategory category,
    required String title,
    required String notes,
    required int amountMinor,
    required SupportedCurrency currency,
    required KayaDateOnly transactionDate,
  }) async {
    _checkNetwork();
    final MoneyTransaction existing = _requireOwnedTransaction(
      authenticatedUserId: authenticatedUserId,
      transactionId: transactionId,
    );
    _validateTransactionPayload(
      type: type,
      category: category,
      title: title,
      notes: notes,
      amountMinor: amountMinor,
      transactionDate: transactionDate,
    );

    final MoneyTransaction updated = existing.copyWith(
      type: type,
      category: category,
      title: title.trim(),
      notes: notes.trim(),
      amountMinor: amountMinor,
      currency: currency,
      transactionDate: transactionDate,
      updatedAt: _clock().toUtc(),
    );
    _transactionsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<void> deleteTransaction({
    required String authenticatedUserId,
    required String transactionId,
  }) async {
    _checkNetwork();
    final MoneyTransaction existing = _requireOwnedTransaction(
      authenticatedUserId: authenticatedUserId,
      transactionId: transactionId,
    );
    _transactionsById.remove(existing.id);
  }

  @override
  Future<List<MonthlyBudget>> fetchMonthlyBudgets({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }

    return _budgetsById.values
        .where((MonthlyBudget b) => b.userId == uid)
        .toList();
  }

  @override
  Future<MonthlyBudget> upsertMonthlyBudget({
    required String authenticatedUserId,
    required int year,
    required int month,
    required SupportedCurrency currency,
    required int overallLimitMinor,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (year < 2000 || year > 2100 || month < 1 || month > 12) {
      throw AuthFailure.validation('Budget month and year are out of range.');
    }
    final String? limitError = MoneyValidators.validatePositiveMinorUnits(
      overallLimitMinor,
      fieldName: 'Monthly budget limit',
    );
    if (limitError != null) {
      throw AuthFailure.validation(limitError);
    }

    MonthlyBudget? existing;
    for (final MonthlyBudget candidate in _budgetsById.values) {
      if (candidate.userId == uid &&
          candidate.year == year &&
          candidate.month == month &&
          candidate.currency == currency) {
        existing = candidate;
        break;
      }
    }

    final DateTime now = _clock().toUtc();
    if (existing != null) {
      final MonthlyBudget updated = existing.copyWith(
        overallLimitMinor: overallLimitMinor,
        updatedAt: now,
      );
      _budgetsById[existing.id] = updated;
      return updated;
    }

    final String id = 'mbd_${_nextBudgetSeq++}';
    final MonthlyBudget created = MonthlyBudget(
      id: id,
      userId: uid,
      year: year,
      month: month,
      currency: currency,
      overallLimitMinor: overallLimitMinor,
      createdAt: now,
      updatedAt: now,
    );
    _budgetsById[id] = created;
    return created;
  }
}
