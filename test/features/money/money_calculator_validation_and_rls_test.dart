import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:kaya/features/money/domain/monthly_budget.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';

void main() {
  group('MoneyFormatter (Decimal-Safe Minor Units)', () {
    test('parses 2-decimal currency values without floating point drift', () {
      expect(
        MoneyFormatter.tryParseMinorUnits('19.99', SupportedCurrency.php),
        1999,
      );
      expect(
        MoneyFormatter.tryParseMinorUnits('1,250.5', SupportedCurrency.php),
        125050,
      );
      expect(
        MoneyFormatter.tryParseMinorUnits('₱500', SupportedCurrency.php),
        50000,
      );
      expect(
        MoneyFormatter.tryParseMinorUnits('.75', SupportedCurrency.usd),
        75,
      );
    });

    test('parses 0-decimal currency (JPY) cleanly and rejects decimals', () {
      expect(
        MoneyFormatter.tryParseMinorUnits('1500', SupportedCurrency.jpy),
        1500,
      );
      expect(
        MoneyFormatter.tryParseMinorUnits('¥2,500', SupportedCurrency.jpy),
        2500,
      );
      expect(
        MoneyFormatter.tryParseMinorUnits('1500.50', SupportedCurrency.jpy),
        isNull,
      );
    });

    test(
      'rejects NaN, Infinity, negative, scientific, and excess decimals',
      () {
        expect(
          MoneyFormatter.tryParseMinorUnits('NaN', SupportedCurrency.php),
          isNull,
        );
        expect(
          MoneyFormatter.tryParseMinorUnits('Infinity', SupportedCurrency.php),
          isNull,
        );
        expect(
          MoneyFormatter.tryParseMinorUnits('-250.00', SupportedCurrency.php),
          isNull,
        );
        expect(
          MoneyFormatter.tryParseMinorUnits('1e4', SupportedCurrency.php),
          isNull,
        );
        expect(
          MoneyFormatter.tryParseMinorUnits('10.123', SupportedCurrency.php),
          isNull,
        );
        expect(
          MoneyFormatter.tryParseMinorUnits('', SupportedCurrency.php),
          isNull,
        );
      },
    );

    test('formats minor units accurately including negative and JPY', () {
      expect(
        MoneyFormatter.formatMinorUnits(125050, SupportedCurrency.php),
        '₱1,250.50',
      );
      expect(
        MoneyFormatter.formatMinorUnits(
          25000,
          SupportedCurrency.usd,
          includePlusSign: true,
        ),
        r'+$250.00',
      );
      expect(
        MoneyFormatter.formatMinorUnits(-50000, SupportedCurrency.php),
        '-₱500.00',
      );
      expect(
        MoneyFormatter.formatMinorUnits(1500, SupportedCurrency.jpy),
        '¥1,500',
      );
    });
  });

  group('MoneyValidators Boundary Checks', () {
    test('rejects invalid titles, notes, amounts, and out-of-range dates', () {
      expect(MoneyValidators.validateTitle('   '), isNotNull);
      expect(MoneyValidators.validateTitle('a' * 121), isNotNull);
      expect(MoneyValidators.validateTitle('Groceries'), isNull);

      expect(MoneyValidators.validateNotes('n' * 501), isNotNull);
      expect(MoneyValidators.validateNotes('Weekly food run'), isNull);

      expect(
        MoneyValidators.validatePositiveAmountInput('0', SupportedCurrency.php),
        isNotNull,
      );
      expect(
        MoneyValidators.validatePositiveAmountInput(
          '-10',
          SupportedCurrency.php,
        ),
        isNotNull,
      );
      expect(
        MoneyValidators.validatePositiveAmountInput(
          'NaN',
          SupportedCurrency.php,
        ),
        isNotNull,
      );
      expect(
        MoneyValidators.validatePositiveAmountInput(
          '150.25',
          SupportedCurrency.jpy,
        ),
        isNotNull,
      );
      expect(
        MoneyValidators.validatePositiveAmountInput(
          '150.25',
          SupportedCurrency.php,
        ),
        isNull,
      );

      expect(
        MoneyValidators.validateTransactionDate(
          const KayaDateOnly(1999, 12, 31),
        ),
        isNotNull,
      );
      expect(
        MoneyValidators.validateTransactionDate(
          const KayaDateOnly(2026, 11, 15),
        ),
        isNull,
      );
    });
  });

  group('SafeToSpendCalculator (Centralized Financial Engine)', () {
    final DateTime nowUtc = DateTime.utc(2026, 11, 15, 10, 0);

    MoneyTransaction tx({
      required String id,
      required TransactionType type,
      required MoneyCategory category,
      required int amountMinor,
      KayaDateOnly date = const KayaDateOnly(2026, 11, 15),
    }) {
      return MoneyTransaction(
        id: id,
        userId: 'usr_a',
        type: type,
        category: category,
        title: id,
        notes: '',
        amountMinor: amountMinor,
        currency: SupportedCurrency.php,
        transactionDate: date,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );
    }

    test('returns unconfigured summary when no records or budget exist', () {
      final FinancialOverviewSummary summary =
          SafeToSpendCalculator.calculateOverview(
            transactions: const <MoneyTransaction>[],
            year: 2026,
            month: 11,
            currency: SupportedCurrency.php,
          );

      expect(summary.health, SafeToSpendHealth.unconfigured);
      expect(summary.totalIncomeMinor, 0);
      expect(summary.totalExpensesMinor, 0);
      expect(summary.availableBalanceMinor, 0);
      expect(summary.safeToSpendMinor, 0);
      expect(summary.hasAnyActivity, isFalse);
    });

    test('uses tighter ceiling of available balance vs remaining budget', () {
      final List<MoneyTransaction> txs = <MoneyTransaction>[
        tx(
          id: 'inc_1',
          type: TransactionType.income,
          category: MoneyCategory.salary,
          amountMinor: 2000000, // 20,000.00
        ),
        tx(
          id: 'exp_1',
          type: TransactionType.expense,
          category: MoneyCategory.food,
          amountMinor: 350000, // 3,500.00
        ),
        // Different month should be excluded from November summary.
        tx(
          id: 'exp_oct',
          type: TransactionType.expense,
          category: MoneyCategory.food,
          amountMinor: 999900,
          date: const KayaDateOnly(2026, 10, 28),
        ),
      ];

      final MonthlyBudget budget = MonthlyBudget(
        id: 'b_1',
        userId: 'usr_a',
        year: 2026,
        month: 11,
        currency: SupportedCurrency.php,
        overallLimitMinor: 1000000, // 10,000.00
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      final FinancialOverviewSummary summary =
          SafeToSpendCalculator.calculateOverview(
            transactions: txs,
            year: 2026,
            month: 11,
            currency: SupportedCurrency.php,
            monthlyBudget: budget,
            unpaidObligationsMinor: 100000, // 1,000.00 reserved
          );

      expect(summary.totalIncomeMinor, 2000000);
      expect(summary.totalExpensesMinor, 350000);
      expect(summary.availableBalanceMinor, 1650000); // 16,500.00
      expect(summary.remainingBudgetMinor, 650000); // 6,500.00
      // Spendable ceiling = min(16,500, 6,500) = 6,500; minus 1,000 = 5,500.00
      expect(summary.safeToSpendMinor, 550000);
      expect(summary.health, SafeToSpendHealth.healthy);
      expect(summary.categoryBreakdowns.single.category, MoneyCategory.food);
    });

    test(
      'evaluates Can I Buy This? across healthy, caution, and over-limit',
      () {
        final FinancialOverviewSummary summary =
            SafeToSpendCalculator.calculateOverview(
              transactions: <MoneyTransaction>[
                tx(
                  id: 'inc_1',
                  type: TransactionType.income,
                  category: MoneyCategory.salary,
                  amountMinor: 1000000, // 10,000.00
                ),
              ],
              year: 2026,
              month: 11,
              currency: SupportedCurrency.php,
            );

        final PurchaseAffordabilityVerdict affordable =
            SafeToSpendCalculator.evaluatePurchase(
              overview: summary,
              plannedAmountMinor: 250000, // 2,500.00
              itemLabel: 'Headphones',
            );
        expect(affordable.canSafelyAfford, isTrue);
        expect(affordable.health, SafeToSpendHealth.healthy);
        expect(affordable.safeToSpendAfterMinor, 750000);

        final PurchaseAffordabilityVerdict tight =
            SafeToSpendCalculator.evaluatePurchase(
              overview: summary,
              plannedAmountMinor: 900000, // 9,000.00 -> leaves 10%
              itemLabel: 'Concert Ticket',
            );
        expect(tight.canSafelyAfford, isTrue);
        expect(tight.health, SafeToSpendHealth.caution);
        expect(tight.safeToSpendAfterMinor, 100000);

        final PurchaseAffordabilityVerdict unaffordable =
            SafeToSpendCalculator.evaluatePurchase(
              overview: summary,
              plannedAmountMinor: 1200000, // 12,000.00
              itemLabel: 'Monitor',
            );
        expect(unaffordable.canSafelyAfford, isFalse);
        expect(unaffordable.health, SafeToSpendHealth.critical);
        expect(unaffordable.shortfallMinor, 200000);
      },
    );
  });

  group('InMemoryMoneyRepository RLS & MoneyController Session Isolation', () {
    test(
      'enforces strict user ownership and clears private cache on logout',
      () async {
        final DateTime fixedNow = DateTime.utc(2026, 11, 15, 9, 0);
        final InMemoryMoneyRepository repo = InMemoryMoneyRepository(
          clock: () => fixedNow,
        );

        final MoneyTransaction userATx = await repo.createTransaction(
          authenticatedUserId: 'usr_a',
          type: TransactionType.income,
          category: MoneyCategory.salary,
          title: 'User A Salary',
          amountMinor: 1500000,
          currency: SupportedCurrency.php,
          transactionDate: const KayaDateOnly(2026, 11, 15),
        );
        await repo.upsertMonthlyBudget(
          authenticatedUserId: 'usr_a',
          year: 2026,
          month: 11,
          currency: SupportedCurrency.php,
          overallLimitMinor: 800000,
        );

        // User B cannot fetch User A records or mutate them.
        expect(
          () => repo.fetchTransactions(
            authenticatedUserId: 'usr_b',
            requestedOwnerId: 'usr_a',
          ),
          throwsA(isA<AuthFailure>()),
        );
        expect(
          () => repo.fetchMonthlyBudgets(
            authenticatedUserId: 'usr_b',
            requestedOwnerId: 'usr_a',
          ),
          throwsA(isA<AuthFailure>()),
        );
        expect(
          () => repo.deleteTransaction(
            authenticatedUserId: 'usr_b',
            transactionId: userATx.id,
          ),
          throwsA(isA<AuthFailure>()),
        );

        // Controller session binding & logout wipe.
        final MoneyController controller = MoneyController(
          repository: repo,
          clock: () => fixedNow,
        );
        await controller.bindAuthenticatedUser('usr_a');
        expect(controller.currentOverview.totalIncomeMinor, 1500000);
        expect(controller.currentOverview.monthlyBudgetLimitMinor, 800000);

        controller.evaluateCanIBuyThis(
          rawAmountInput: '1000',
          itemLabel: 'Coffee Machine',
        );
        expect(controller.lastPurchaseVerdict, isNotNull);

        // Logout immediately clears all cached financial data and purchase estimates.
        await controller.bindAuthenticatedUser(null);
        expect(controller.currentOverview.totalIncomeMinor, 0);
        expect(controller.currentOverview.monthlyBudgetLimitMinor, isNull);
        expect(controller.periodTransactions, isEmpty);
        expect(controller.lastPurchaseVerdict, isNull);

        // Switching to User B exposes zero User A data.
        await controller.bindAuthenticatedUser('usr_b');
        expect(controller.periodTransactions, isEmpty);
        expect(controller.currentOverview.hasAnyActivity, isFalse);
      },
    );
  });
}
