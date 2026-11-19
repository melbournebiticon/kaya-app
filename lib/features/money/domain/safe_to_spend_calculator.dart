import 'dart:math' as math;

import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:kaya/features/money/domain/monthly_budget.dart';

/// Health status of the user's Safe to Spend and monthly budget position.
enum SafeToSpendHealth {
  healthy(label: 'Healthy Cushion'),
  caution(label: 'Watch Spending'),
  critical(label: 'Over / Depleted'),
  unconfigured(label: 'No Data Yet');

  const SafeToSpendHealth({required this.label});

  final String label;
}

/// Aggregated actual spending per expense category for a period.
class CategorySpendBreakdown {
  const CategorySpendBreakdown({
    required this.category,
    required this.spentMinor,
    required this.shareOfExpensesRatio,
  });

  final MoneyCategory category;
  final int spentMinor;
  final double shareOfExpensesRatio;
}

/// Single authoritative financial overview produced exclusively by
/// [SafeToSpendCalculator].
class FinancialOverviewSummary {
  const FinancialOverviewSummary({
    required this.year,
    required this.month,
    required this.currency,
    required this.totalIncomeMinor,
    required this.totalExpensesMinor,
    required this.availableBalanceMinor,
    required this.monthlyBudgetLimitMinor,
    required this.remainingBudgetMinor,
    required this.unpaidObligationsMinor,
    required this.safeToSpendMinor,
    required this.budgetUtilizationRatio,
    required this.health,
    required this.categoryBreakdowns,
    required this.transactionCount,
  });

  final int year;
  final int month;
  final SupportedCurrency currency;
  final int totalIncomeMinor;
  final int totalExpensesMinor;
  final int availableBalanceMinor;
  final int? monthlyBudgetLimitMinor;
  final int? remainingBudgetMinor;
  final int unpaidObligationsMinor;
  final int safeToSpendMinor;
  final double? budgetUtilizationRatio;
  final SafeToSpendHealth health;
  final List<CategorySpendBreakdown> categoryBreakdowns;
  final int transactionCount;

  bool get hasBudget => monthlyBudgetLimitMinor != null;

  bool get hasAnyActivity =>
      transactionCount > 0 || hasBudget || unpaidObligationsMinor > 0;

  /// Non-negative spendable amount shown as actionable spending power.
  int get positiveSafeToSpendMinor =>
      safeToSpendMinor > 0 ? safeToSpendMinor : 0;

  /// Deficit amount if Safe to Spend has dropped below zero.
  int get deficitMinor => safeToSpendMinor < 0 ? -safeToSpendMinor : 0;
}

/// Deterministic evaluation returned by `"Can I Buy This?"` without ever
/// modifying actual recorded transactions.
class PurchaseAffordabilityVerdict {
  const PurchaseAffordabilityVerdict({
    required this.itemLabel,
    required this.plannedAmountMinor,
    required this.currency,
    required this.canSafelyAfford,
    required this.safeToSpendBeforeMinor,
    required this.safeToSpendAfterMinor,
    required this.shortfallMinor,
    required this.headline,
    required this.explanation,
    required this.health,
  });

  final String itemLabel;
  final int plannedAmountMinor;
  final SupportedCurrency currency;
  final bool canSafelyAfford;
  final int safeToSpendBeforeMinor;
  final int safeToSpendAfterMinor;
  final int shortfallMinor;
  final String headline;
  final String explanation;
  final SafeToSpendHealth health;
}

/// Single centralized financial calculation engine for KAYA.
///
/// Architectural Mandate (Section 3, Phase 4):
/// "Use one centralized financial calculation. Never duplicate Safe to Spend
/// formulas in multiple screens. Financial calculations must use a
/// decimal-safe strategy or integer minor currency units."
abstract final class SafeToSpendCalculator {
  /// Calculates the authoritative monthly overview for [year]/[month] and
  /// [currency] using integer minor currency units.
  ///
  /// [unpaidObligationsMinor] defaults to `0` in Phase 4 and accepts unpaid
  /// bills in Phase 5+ so the formula stays unified across phases.
  static FinancialOverviewSummary calculateOverview({
    required Iterable<MoneyTransaction> transactions,
    required int year,
    required int month,
    required SupportedCurrency currency,
    MonthlyBudget? monthlyBudget,
    int unpaidObligationsMinor = 0,
  }) {
    final int safeObligationsMinor = unpaidObligationsMinor < 0
        ? 0
        : unpaidObligationsMinor;

    int totalIncomeMinor = 0;
    int totalExpensesMinor = 0;
    int transactionCount = 0;
    final Map<MoneyCategory, int> expenseByCategory = <MoneyCategory, int>{};

    for (final MoneyTransaction tx in transactions) {
      if (tx.currency != currency ||
          tx.transactionDate.year != year ||
          tx.transactionDate.month != month) {
        continue;
      }
      transactionCount++;
      if (tx.type == TransactionType.income) {
        totalIncomeMinor += tx.amountMinor;
      } else {
        totalExpensesMinor += tx.amountMinor;
        expenseByCategory.update(
          tx.category,
          (int current) => current + tx.amountMinor,
          ifAbsent: () => tx.amountMinor,
        );
      }
    }

    final int availableBalanceMinor = totalIncomeMinor - totalExpensesMinor;

    final MonthlyBudget? matchingBudget =
        (monthlyBudget != null &&
            monthlyBudget.year == year &&
            monthlyBudget.month == month &&
            monthlyBudget.currency == currency)
        ? monthlyBudget
        : null;

    final int? budgetLimitMinor = matchingBudget?.overallLimitMinor;
    final int? remainingBudgetMinor = budgetLimitMinor != null
        ? budgetLimitMinor - totalExpensesMinor
        : null;

    final int spendableCeilingMinor;
    if (remainingBudgetMinor != null && totalIncomeMinor > 0) {
      // Never allow spending past either available cash OR remaining budget.
      spendableCeilingMinor = math.min(
        availableBalanceMinor,
        remainingBudgetMinor,
      );
    } else if (remainingBudgetMinor != null) {
      // Budget configured prior to logging income transactions.
      spendableCeilingMinor = remainingBudgetMinor;
    } else {
      spendableCeilingMinor = availableBalanceMinor;
    }

    final int safeToSpendMinor = spendableCeilingMinor - safeObligationsMinor;

    final double? utilizationRatio =
        (budgetLimitMinor != null && budgetLimitMinor > 0)
        ? totalExpensesMinor / budgetLimitMinor
        : null;

    final SafeToSpendHealth health;
    if (transactionCount == 0 &&
        budgetLimitMinor == null &&
        safeObligationsMinor == 0) {
      health = SafeToSpendHealth.unconfigured;
    } else if (safeToSpendMinor <= 0 ||
        (remainingBudgetMinor != null && remainingBudgetMinor < 0)) {
      health = SafeToSpendHealth.critical;
    } else if ((utilizationRatio != null && utilizationRatio >= 0.80) ||
        (totalIncomeMinor > 0 && (safeToSpendMinor * 5) <= totalIncomeMinor)) {
      health = SafeToSpendHealth.caution;
    } else {
      health = SafeToSpendHealth.healthy;
    }

    final List<CategorySpendBreakdown> breakdowns =
        expenseByCategory.entries
            .map(
              (MapEntry<MoneyCategory, int> e) => CategorySpendBreakdown(
                category: e.key,
                spentMinor: e.value,
                shareOfExpensesRatio: totalExpensesMinor > 0
                    ? e.value / totalExpensesMinor
                    : 0.0,
              ),
            )
            .toList()
          ..sort(
            (CategorySpendBreakdown a, CategorySpendBreakdown b) =>
                b.spentMinor.compareTo(a.spentMinor),
          );

    return FinancialOverviewSummary(
      year: year,
      month: month,
      currency: currency,
      totalIncomeMinor: totalIncomeMinor,
      totalExpensesMinor: totalExpensesMinor,
      availableBalanceMinor: availableBalanceMinor,
      monthlyBudgetLimitMinor: budgetLimitMinor,
      remainingBudgetMinor: remainingBudgetMinor,
      unpaidObligationsMinor: safeObligationsMinor,
      safeToSpendMinor: safeToSpendMinor,
      budgetUtilizationRatio: utilizationRatio,
      health: health,
      categoryBreakdowns: List<CategorySpendBreakdown>.unmodifiable(breakdowns),
      transactionCount: transactionCount,
    );
  }

  /// Evaluates a hypothetical purchase against the current [overview] without
  /// recording an actual expense transaction.
  static PurchaseAffordabilityVerdict evaluatePurchase({
    required FinancialOverviewSummary overview,
    required int plannedAmountMinor,
    String itemLabel = '',
  }) {
    final String cleanLabel = itemLabel.trim();
    final SupportedCurrency currency = overview.currency;
    final String formattedPlanned = MoneyFormatter.formatMinorUnits(
      plannedAmountMinor,
      currency,
    );

    if (overview.health == SafeToSpendHealth.unconfigured) {
      return PurchaseAffordabilityVerdict(
        itemLabel: cleanLabel,
        plannedAmountMinor: plannedAmountMinor,
        currency: currency,
        canSafelyAfford: false,
        safeToSpendBeforeMinor: 0,
        safeToSpendAfterMinor: -plannedAmountMinor,
        shortfallMinor: plannedAmountMinor,
        headline: 'Not Enough Data Yet',
        explanation:
            'Add your monthly income or set a monthly budget first so KAYA can evaluate $formattedPlanned against real numbers.',
        health: SafeToSpendHealth.caution,
      );
    }

    final int before = overview.safeToSpendMinor;
    final int after = before - plannedAmountMinor;
    final String subject = cleanLabel.isNotEmpty
        ? '"$cleanLabel" ($formattedPlanned)'
        : formattedPlanned;

    if (before <= 0 || after < 0) {
      final int shortfall = before <= 0
          ? (plannedAmountMinor + (-before))
          : -after;
      final String formattedShortfall = MoneyFormatter.formatMinorUnits(
        shortfall,
        currency,
      );
      return PurchaseAffordabilityVerdict(
        itemLabel: cleanLabel,
        plannedAmountMinor: plannedAmountMinor,
        currency: currency,
        canSafelyAfford: false,
        safeToSpendBeforeMinor: before,
        safeToSpendAfterMinor: after,
        shortfallMinor: shortfall,
        headline: 'No — Exceeds Safe to Spend',
        explanation:
            'Buying $subject exceeds your Safe to Spend by $formattedShortfall.',
        health: SafeToSpendHealth.critical,
      );
    }

    final String formattedAfter = MoneyFormatter.formatMinorUnits(
      after,
      currency,
    );
    // Caution when remaining Safe to Spend would drop to 0 or under 20% of current cushion.
    if (after == 0 || (after * 5) < before) {
      return PurchaseAffordabilityVerdict(
        itemLabel: cleanLabel,
        plannedAmountMinor: plannedAmountMinor,
        currency: currency,
        canSafelyAfford: true,
        safeToSpendBeforeMinor: before,
        safeToSpendAfterMinor: after,
        shortfallMinor: 0,
        headline: 'Caution — Tight on Safe to Spend',
        explanation:
            '$subject fits today, leaving $formattedAfter in Safe to Spend for the rest of the month.',
        health: SafeToSpendHealth.caution,
      );
    }

    return PurchaseAffordabilityVerdict(
      itemLabel: cleanLabel,
      plannedAmountMinor: plannedAmountMinor,
      currency: currency,
      canSafelyAfford: true,
      safeToSpendBeforeMinor: before,
      safeToSpendAfterMinor: after,
      shortfallMinor: 0,
      headline: 'Yes — Within Safe to Spend',
      explanation:
          '$subject fits comfortably, leaving $formattedAfter in Safe to Spend.',
      health: SafeToSpendHealth.healthy,
    );
  }
}
