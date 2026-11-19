import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/data/in_memory_life_organization_repository.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Phase 7 Life Organization UI, Today Routines & Shopping Tests', () {
    testWidgets(
      'manages checklists with reset, routines with Today streak badge, and shopping lists without altering Money expenses',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 980);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 9, 0);
        final MoneyController moneyCtrl = MoneyController(
          repository: InMemoryMoneyRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p7_qa',
          initialCurrency: SupportedCurrency.php,
        );
        final LifeOrganizationController orgCtrl = LifeOrganizationController(
          repository: InMemoryLifeOrganizationRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p7_qa',
          initialCurrency: SupportedCurrency.php,
        );

        await moneyCtrl.loadMoneyData();
        await orgCtrl.loadAll();

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            moneyController: moneyCtrl,
            lifeOrganizationController: orgCtrl,
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Life module.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Life'),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Daily Routines sub-tab: Create routine, complete step today, check Today badge.
        await tester.tap(
          find.byKey(const ValueKey<String>('life_subtab_routines')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('routines_create_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('routine_form_title_field')),
          'Morning Reset',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('routine_form_step_field')),
          'Drink water',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('routine_form_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Morning Reset'), findsOneWidget);
        expect(find.text('Drink water'), findsOneWidget);

        final String stepId = orgCtrl.routines.single.steps.single.id;
        await tester.tap(
          find.byKey(ValueKey<String>('routine_step_toggle_$stepId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 day streak'), findsOneWidget);
        expect(find.text('Done today'), findsOneWidget);

        // Verify TodayScreen displays Routines today: 1/1.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Today'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('today_routines_badge')),
          findsOneWidget,
        );
        expect(find.text('Routines today: 1/1'), findsOneWidget);

        // Return to Life module -> Smart Checklists sub-tab.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Life'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('life_subtab_checklists')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('checklists_create_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('checklist_form_title_field')),
          'Trip Packing',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('checklist_form_save_button')),
        );
        await tester.pumpAndSettle();

        final String chkId = orgCtrl.checklists.single.id;
        await tester.enterText(
          find.byKey(ValueKey<String>('checklist_add_item_field_$chkId')),
          'Powerbank',
        );
        await tester.tap(
          find.byKey(ValueKey<String>('checklist_add_item_button_$chkId')),
        );
        await tester.pumpAndSettle();

        final String chkItemId = orgCtrl.checklists.single.items.single.id;
        await tester.tap(
          find.byKey(ValueKey<String>('checklist_item_toggle_$chkItemId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 of 1 done'), findsOneWidget);

        // Reset checked items with confirmation dialog.
        await tester.tap(
          find.byKey(ValueKey<String>('checklist_reset_$chkId')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Reset Checked Items?'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Items'));
        await tester.pumpAndSettle();
        expect(find.text('0 of 1 done'), findsOneWidget);

        // 3. Shopping Lists sub-tab: Add items, toggle purchased, verify expense isolation.
        await tester.tap(
          find.byKey(const ValueKey<String>('life_subtab_shopping')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('shopping_create_list_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('shopping_list_title_field')),
          'Weekly Groceries',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('shopping_list_save_button')),
        );
        await tester.pumpAndSettle();

        final String listId = orgCtrl.shoppingLists.single.id;
        await tester.tap(
          find.byKey(ValueKey<String>('shopping_add_product_button_$listId')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('shopping_product_name_field')),
          'Fresh Milk',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('shopping_product_qty_field')),
          '2',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('shopping_product_price_field')),
          '85.50',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('shopping_product_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Est. Total: ₱171.00'), findsOneWidget);
        expect(find.text('Remaining: ₱171.00'), findsOneWidget);

        final String productId = orgCtrl.shoppingLists.single.items.single.id;
        await tester.tap(
          find.byKey(ValueKey<String>('shopping_product_toggle_$productId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Est. Total: ₱171.00'), findsOneWidget);
        expect(find.text('Remaining: ₱0.00'), findsOneWidget);

        // Critical financial isolation rule: estimated shopping items are NEVER recorded as expenses!
        expect(moneyCtrl.currentOverview.totalExpensesMinor, 0);
      },
    );
  });
}
