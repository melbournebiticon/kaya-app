import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/data/in_memory_bill_repository.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/data/in_memory_reminder_repository.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Phase 5 Bills & Reminders UI, Today & Safe to Spend Integration', () {
    testWidgets(
      'creates recurring bill & reminder, shows Today priority items, reserves unpaid bill in Safe to Spend, and updates on confirmed Paid',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 980);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 10, 0);
        final MoneyController moneyCtrl = MoneyController(
          repository: InMemoryMoneyRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p5_qa',
          initialCurrency: SupportedCurrency.php,
        );
        final BillController billCtrl = BillController(
          repository: InMemoryBillRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p5_qa',
          initialCurrency: SupportedCurrency.php,
        );
        final ReminderController remCtrl = ReminderController(
          repository: InMemoryReminderRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p5_qa',
        );

        await moneyCtrl.loadMoneyData();
        await billCtrl.loadBills();
        await remCtrl.loadReminders();

        // Seed ₱20,000.00 income in Money module.
        await moneyCtrl.createTransaction(
          type: TransactionType.income,
          category: MoneyCategory.salary,
          title: 'Monthly Payroll',
          amountMinor: 2000000,
          transactionDate: const KayaDateOnly(2026, 11, 16),
        );

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            moneyController: moneyCtrl,
            billController: billCtrl,
            reminderController: remCtrl,
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Life module and open Bills & Reminders sub-tab.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Life'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('life_subtab_bills')),
        );
        await tester.pumpAndSettle();

        // 1. Add a recurring monthly bill (₱2,000.00 due today Nov 16, 2026).
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('bills_add_button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('bills_add_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('bill_form_title_field')),
          'Meralco Electric',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('bill_form_amount_field')),
          '2000',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('bill_form_recurrence_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Monthly').last);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('bill_form_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Meralco Electric'), findsOneWidget);
        expect(find.text('₱2,000.00'), findsWidgets);

        // 2. Add a reminder due today.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('reminders_add_button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('reminders_add_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('reminder_form_title_field')),
          'Call Barangay Office',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('reminder_form_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Call Barangay Office'), findsOneWidget);

        // 3. Check Today module shows both priority items and Safe to Spend = ₱18,000.00.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Today'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Safe to Spend: ₱18,000.00'), findsOneWidget);
        expect(find.text('Meralco Electric'), findsOneWidget);
        expect(find.text('Call Barangay Office'), findsOneWidget);

        // 4. Check Money module displays Unpaid Bills Reserved: ₱2,000.00.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Money'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('money_unpaid_bills_reserved_badge'),
          ),
          findsOneWidget,
        );
        expect(find.text('Unpaid Bills Reserved: ₱2,000.00'), findsOneWidget);
        expect(find.text('₱18,000.00'), findsOneWidget);

        // 5. Return to Life module, mark Meralco Electric as Paid via confirmation dialog.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Life'),
          ),
        );
        await tester.pumpAndSettle();

        final String billId = billCtrl.unpaidBills.single.id;
        await tester.ensureVisible(
          find.byKey(ValueKey<String>('bill_toggle_paid_$billId')),
        );
        await tester.tap(
          find.byKey(ValueKey<String>('bill_toggle_paid_$billId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mark Bill as Paid?'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Mark Paid'));
        await tester.pumpAndSettle();

        expect(find.text('Undo'), findsOneWidget);
        // Next cycle recurring bill (Dec 16, 2026) is automatically scheduled as Upcoming!
        expect(billCtrl.upcomingBills.length, 1);
        expect(
          billCtrl.upcomingBills.single.dueDate,
          const KayaDateOnly(2026, 12, 16),
        );
        expect(
          billCtrl.allBills.firstWhere((b) => b.id == billId).recurrence,
          BillRecurrence.monthly,
        );

        // 6. Verify Money module now excludes the paid bill from unpaid obligations.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Money'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('money_unpaid_bills_reserved_badge'),
          ),
          findsNothing,
        );
        expect(find.text('₱20,000.00'), findsWidgets);

        // 7. Complete and delete the reminder with confirmations in Life module.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Life'),
          ),
        );
        await tester.pumpAndSettle();

        ScaffoldMessenger.of(
          tester.element(
            find.byKey(const ValueKey<String>('bills_add_button')),
          ),
        ).hideCurrentSnackBar();
        await tester.pumpAndSettle();

        final String remId = remCtrl.activeReminders.single.id;
        await tester.ensureVisible(
          find.byKey(ValueKey<String>('reminder_toggle_$remId')),
        );
        await tester.tap(
          find.byKey(ValueKey<String>('reminder_toggle_$remId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Complete Reminder?'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Mark Completed'));
        await tester.pumpAndSettle();
        expect(remCtrl.completedReminders.length, 1);

        // Switch Reminders filter to Completed and delete it.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('reminder_filter_completed')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('reminder_filter_completed')),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(ValueKey<String>('reminder_delete_$remId')),
        );
        await tester.tap(
          find.byKey(ValueKey<String>('reminder_delete_$remId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Delete Reminder?'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Delete Reminder'),
        );
        await tester.pumpAndSettle();
        expect(remCtrl.allReminders, isEmpty);
      },
    );
  });
}
