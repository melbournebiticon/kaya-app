import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Phase 4 Money Management UI & Today Integration Tests', () {
    testWidgets(
      'records income & expense, configures monthly budget, runs Can I Buy This without altering expenses, and syncs Safe to Spend with Today',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 980);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime.utc(2026, 11, 15, 10, 0);
        final InMemoryMoneyRepository repo = InMemoryMoneyRepository(
          clock: () => fixedNow,
        );
        final MoneyController moneyController = MoneyController(
          repository: repo,
          clock: () => fixedNow,
          initialUserId: 'usr_money_qa',
          initialCurrency: SupportedCurrency.php,
        );
        await moneyController.loadMoneyData();

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            moneyController: moneyController,
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Money module.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Money'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Safe to Spend'), findsOneWidget);
        expect(find.text('No Financial Records Yet'), findsOneWidget);

        // 1. Add Income: ₱20,000.00
        await tester.tap(
          find.byKey(const ValueKey<String>('money_add_income_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('tx_form_title_field')),
          'November Salary',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('tx_form_amount_field')),
          '20000',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('tx_form_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('November Salary'), findsOneWidget);
        expect(find.text('₱20,000.00'), findsWidgets);

        // 2. Add Expense: ₱4,500.50
        await tester.tap(
          find.byKey(const ValueKey<String>('money_add_expense_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('tx_form_title_field')),
          'Grocery Stockup',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('tx_form_amount_field')),
          '4500.50',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('tx_form_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Grocery Stockup'), findsOneWidget);
        // Available Balance and Safe to Spend are both ₱15,499.50 before budget.
        expect(find.text('₱15,499.50'), findsWidgets);

        // 3. Set Monthly Budget: ₱10,000.00 -> Remaining budget ₱5,499.50 becomes tighter ceiling!
        await tester.tap(
          find.byKey(const ValueKey<String>('money_set_budget_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('budget_form_limit_field')),
          '10000',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('budget_form_save_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('money_safe_to_spend_value')),
          findsOneWidget,
        );
        expect(find.text('₱5,499.50'), findsOneWidget);

        // 4. Use "Can I Buy This?" (estimate only; must NOT add an expense)
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('can_i_buy_amount_field')),
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('can_i_buy_item_field')),
          'Jacket',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('can_i_buy_amount_field')),
          '2000',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('can_i_buy_check_button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('can_i_buy_check_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Yes — Within Safe to Spend'), findsOneWidget);
        // Actual expense total stays ₱4,500.50 and Safe to Spend remains ₱5,499.50.
        expect(moneyController.currentOverview.totalExpensesMinor, 450050);
        expect(moneyController.currentOverview.safeToSpendMinor, 549950);

        // Now test an unaffordable planned purchase (₱8,000.00).
        await tester.enterText(
          find.byKey(const ValueKey<String>('can_i_buy_amount_field')),
          '8000',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('can_i_buy_check_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('No — Exceeds Safe to Spend'), findsOneWidget);
        expect(moneyController.currentOverview.totalExpensesMinor, 450050);

        // 5. Switch to Today module and verify centralized Safe to Spend badge.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Today'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('today_safe_to_spend_badge')),
          findsOneWidget,
        );
        expect(find.text('Safe to Spend: ₱5,499.50'), findsOneWidget);

        // 6. Switch back to Money and confirm delete removes transaction after prompt.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Money'),
          ),
        );
        await tester.pumpAndSettle();

        final String expenseId = moneyController.periodTransactions
            .firstWhere((tx) => tx.title == 'Grocery Stockup')
            .id;

        await tester.ensureVisible(
          find.byKey(ValueKey<String>('tx_delete_$expenseId')),
        );
        await tester.tap(find.byKey(ValueKey<String>('tx_delete_$expenseId')));
        await tester.pumpAndSettle();

        expect(find.text('Delete Transaction?'), findsOneWidget);
        await tester.tap(find.text('Delete Transaction'));
        await tester.pumpAndSettle();

        expect(find.text('Grocery Stockup'), findsNothing);
        expect(moneyController.currentOverview.totalExpensesMinor, 0);
        expect(moneyController.currentOverview.safeToSpendMinor, 1000000);
      },
    );
  });
}
