import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:kaya/features/money/domain/monthly_budget.dart';

/// Repository contract for Phase 4 Money Management.
///
/// Mirrors the PostgreSQL Row Level Security policies in
/// `supabase/migrations/20261114000003_phase4_money.sql`.
abstract class MoneyRepository {
  Future<List<MoneyTransaction>> fetchTransactions({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  Future<MoneyTransaction> createTransaction({
    required String authenticatedUserId,
    required TransactionType type,
    required MoneyCategory category,
    required String title,
    String notes = '',
    required int amountMinor,
    required SupportedCurrency currency,
    required KayaDateOnly transactionDate,
  });

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
  });

  Future<void> deleteTransaction({
    required String authenticatedUserId,
    required String transactionId,
  });

  Future<List<MonthlyBudget>> fetchMonthlyBudgets({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  Future<MonthlyBudget> upsertMonthlyBudget({
    required String authenticatedUserId,
    required int year,
    required int month,
    required SupportedCurrency currency,
    required int overallLimitMinor,
  });
}
