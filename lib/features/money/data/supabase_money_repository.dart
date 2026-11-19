import 'package:kaya/core/data/supabase_error_mapper.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_repository.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:kaya/features/money/domain/monthly_budget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live Supabase implementation of [MoneyRepository] (Phase 4).
class SupabaseMoneyRepository implements MoneyRepository {
  SupabaseMoneyRepository({required this.client});

  final SupabaseClient client;

  MoneyTransaction _txFromRow(Map<String, dynamic> row) {
    final TransactionType type =
        TransactionType.tryFromDbValue(row['type'] as String?) ??
        TransactionType.expense;
    final MoneyCategory category =
        MoneyCategory.tryFromDbValue(row['category'] as String?) ??
        MoneyCategory.defaultForType(type);
    final SupportedCurrency currency =
        SupportedCurrency.tryFromCode(row['currency'] as String?) ??
        SupportedCurrency.php;

    return MoneyTransaction(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      type: type,
      category: category,
      title: (row['title'] as String? ?? '').trim(),
      notes: (row['notes'] as String? ?? '').trim(),
      amountMinor: SupabaseErrorMapper.parseInt(row['amount_minor']),
      currency: currency,
      transactionDate: SupabaseErrorMapper.parseDateOnly(
        row['transaction_date'],
      ),
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  MonthlyBudget _budgetFromRow(Map<String, dynamic> row) {
    final SupportedCurrency currency =
        SupportedCurrency.tryFromCode(row['currency'] as String?) ??
        SupportedCurrency.php;
    return MonthlyBudget(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      year: SupabaseErrorMapper.parseInt(row['year']),
      month: SupabaseErrorMapper.parseInt(row['month']),
      currency: currency,
      overallLimitMinor: SupabaseErrorMapper.parseInt(
        row['overall_limit_minor'],
      ),
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  void _validateTransaction({
    required TransactionType type,
    required MoneyCategory category,
    required String title,
    required String notes,
    required int amountMinor,
    required KayaDateOnly transactionDate,
  }) {
    final String? titleErr = MoneyValidators.validateTitle(title);
    if (titleErr != null) {
      throw AuthFailure.validation(titleErr);
    }
    final String? notesErr = MoneyValidators.validateNotes(notes);
    if (notesErr != null) {
      throw AuthFailure.validation(notesErr);
    }
    final String? amountErr = MoneyValidators.validatePositiveMinorUnits(
      amountMinor,
    );
    if (amountErr != null) {
      throw AuthFailure.validation(amountErr);
    }
    final String? dateErr = MoneyValidators.validateTransactionDate(
      transactionDate,
    );
    if (dateErr != null) {
      throw AuthFailure.validation(dateErr);
    }
    if (category.transactionType != type) {
      throw AuthFailure.validation(
        'Selected category does not match ${type.label}.',
      );
    }
  }

  @override
  Future<List<MoneyTransaction>> fetchTransactions({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
      requestedOwnerId: requestedOwnerId,
    );
    try {
      final List<dynamic> rows = await client
          .from('money_transactions')
          .select()
          .eq('user_id', uid)
          .order('transaction_date', ascending: false);
      return rows
          .map(
            (dynamic row) => _txFromRow(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Unable to load financial transactions.');
    }
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
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateTransaction(
      type: type,
      category: category,
      title: title,
      notes: notes,
      amountMinor: amountMinor,
      transactionDate: transactionDate,
    );
    try {
      final Map<String, dynamic> inserted = await client
          .from('money_transactions')
          .insert(<String, dynamic>{
            'user_id': uid,
            'type': type.dbValue,
            'category': category.dbValue,
            'title': title.trim(),
            'notes': notes.trim(),
            'amount_minor': amountMinor,
            'currency': currency.code,
            'transaction_date': transactionDate.toIsoDateString(),
          })
          .select()
          .single();
      return _txFromRow(inserted);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to save transaction.');
    }
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
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateTransaction(
      type: type,
      category: category,
      title: title,
      notes: notes,
      amountMinor: amountMinor,
      transactionDate: transactionDate,
    );
    try {
      final Map<String, dynamic> updated = await client
          .from('money_transactions')
          .update(<String, dynamic>{
            'type': type.dbValue,
            'category': category.dbValue,
            'title': title.trim(),
            'notes': notes.trim(),
            'amount_minor': amountMinor,
            'currency': currency.code,
            'transaction_date': transactionDate.toIsoDateString(),
          })
          .eq('id', transactionId)
          .eq('user_id', uid)
          .select()
          .single();
      return _txFromRow(updated);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update transaction.');
    }
  }

  @override
  Future<void> deleteTransaction({
    required String authenticatedUserId,
    required String transactionId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('money_transactions')
          .delete()
          .eq('id', transactionId)
          .eq('user_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to delete transaction.');
    }
  }

  @override
  Future<List<MonthlyBudget>> fetchMonthlyBudgets({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
      requestedOwnerId: requestedOwnerId,
    );
    try {
      final List<dynamic> rows = await client
          .from('monthly_budgets')
          .select()
          .eq('user_id', uid);
      return rows
          .map(
            (dynamic row) =>
                _budgetFromRow(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Unable to load monthly budgets.');
    }
  }

  @override
  Future<MonthlyBudget> upsertMonthlyBudget({
    required String authenticatedUserId,
    required int year,
    required int month,
    required SupportedCurrency currency,
    required int overallLimitMinor,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    final String? limitErr = MoneyValidators.validatePositiveMinorUnits(
      overallLimitMinor,
      fieldName: 'Monthly budget',
    );
    if (limitErr != null) {
      throw AuthFailure.validation(limitErr);
    }
    try {
      final Map<String, dynamic> saved = await client
          .from('monthly_budgets')
          .upsert(<String, dynamic>{
            'user_id': uid,
            'year': year,
            'month': month,
            'currency': currency.code,
            'overall_limit_minor': overallLimitMinor,
          }, onConflict: 'user_id,year,month,currency')
          .select()
          .single();
      return _budgetFromRow(saved);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to save monthly budget.');
    }
  }
}
