import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/bill_reminder_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/data/in_memory_bill_repository.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/data/in_memory_reminder_repository.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';

void main() {
  group('KayaDateOnly Recurring Month & Leap-Year Calculations', () {
    test('clamps end-of-month dates accurately on addMonths and addYears', () {
      expect(
        const KayaDateOnly(2026, 1, 31).addMonths(1),
        const KayaDateOnly(2026, 2, 28),
      );
      expect(
        const KayaDateOnly(2024, 1, 31).addMonths(1),
        const KayaDateOnly(2024, 2, 29),
      );
      expect(
        const KayaDateOnly(2024, 2, 29).addYears(1),
        const KayaDateOnly(2025, 2, 28),
      );
      expect(
        const KayaDateOnly(2026, 11, 16).addMonths(2),
        const KayaDateOnly(2027, 1, 16),
      );
    });
  });

  group('BillReminderValidators Boundary Checks', () {
    test('validates titles, notes, due dates, and positive bill amounts', () {
      expect(BillReminderValidators.validateTitle('  '), isNotNull);
      expect(BillReminderValidators.validateTitle('x' * 121), isNotNull);
      expect(BillReminderValidators.validateTitle('Water Utility'), isNull);

      expect(BillReminderValidators.validateNotes('n' * 501), isNotNull);
      expect(BillReminderValidators.validateNotes('Auto-debit'), isNull);

      expect(
        BillReminderValidators.validateDueDate(
          const KayaDateOnly(1999, 12, 31),
        ),
        isNotNull,
      );
      expect(
        BillReminderValidators.validateDueDate(
          const KayaDateOnly(2026, 11, 16),
        ),
        isNull,
      );

      expect(
        BillReminderValidators.validateBillAmountInput(
          '0',
          SupportedCurrency.php,
        ),
        isNotNull,
      );
      expect(
        BillReminderValidators.validateBillAmountInput(
          '-500',
          SupportedCurrency.php,
        ),
        isNotNull,
      );
      expect(
        BillReminderValidators.validateBillAmountInput(
          'NaN',
          SupportedCurrency.php,
        ),
        isNotNull,
      );
      expect(
        BillReminderValidators.validateBillAmountInput(
          '1250.50',
          SupportedCurrency.php,
        ),
        isNull,
      );
    });
  });

  group('Recurring Bill Non-Duplication & Safe to Spend Integration', () {
    test('excludes paid bills from Safe to Spend and never duplicates recurring cycles', () async {
      final DateTime fixedNow = DateTime.utc(2026, 11, 16, 9, 0);
      final InMemoryMoneyRepository moneyRepo = InMemoryMoneyRepository(
        clock: () => fixedNow,
      );
      final InMemoryBillRepository billRepo = InMemoryBillRepository(
        clock: () => fixedNow,
      );

      final MoneyController moneyCtrl = MoneyController(
        repository: moneyRepo,
        clock: () => fixedNow,
        initialUserId: 'usr_a',
        initialCurrency: SupportedCurrency.php,
      );
      final BillController billCtrl = BillController(
        repository: billRepo,
        clock: () => fixedNow,
        initialUserId: 'usr_a',
        initialCurrency: SupportedCurrency.php,
      );

      moneyCtrl.bindUnpaidObligationsSource(
        resolver: (int year, int month, SupportedCurrency currency) =>
            billCtrl.unpaidObligationsMinorForPeriod(
              year: year,
              month: month,
              currency: currency,
            ),
        listenable: billCtrl,
      );

      await moneyCtrl.loadMoneyData();
      await billCtrl.loadBills();

      // Add ₱20,000.00 monthly income.
      await moneyCtrl.createTransaction(
        type: TransactionType.income,
        category: MoneyCategory.salary,
        title: 'Salary',
        amountMinor: 2000000,
        transactionDate: const KayaDateOnly(2026, 11, 16),
      );

      // Add monthly recurring internet bill ₱2,500.00 due Nov 16, 2026.
      final bool created = await billCtrl.createBill(
        title: 'Fiber Internet',
        category: BillCategory.internetPhone,
        amountMinor: 250000,
        dueDate: const KayaDateOnly(2026, 11, 16),
        recurrence: BillRecurrence.monthly,
      );
      expect(created, isTrue);

      // Unpaid bill reduces Safe to Spend from ₱20,000 to ₱17,500.
      expect(moneyCtrl.currentOverview.unpaidObligationsMinor, 250000);
      expect(moneyCtrl.currentOverview.safeToSpendMinor, 1750000);

      final BillItem novBill = billCtrl.allBills.single;

      // Mark November bill as Paid -> spawns December cycle once and excludes
      // both paid November bill and future December bill from November Safe to Spend.
      final result1 = await billCtrl.setBillPaid(
        billId: novBill.id,
        isPaid: true,
      );
      expect(result1?.spawnedNextBill, isNotNull);
      expect(
        result1!.spawnedNextBill!.dueDate,
        const KayaDateOnly(2026, 12, 16),
      );
      expect(billCtrl.allBills.length, 2);
      expect(moneyCtrl.currentOverview.unpaidObligationsMinor, 0);
      expect(moneyCtrl.currentOverview.safeToSpendMinor, 2000000);

      // Undo (mark unpaid) and re-pay November bill -> must NOT create a 3rd duplicate cycle!
      await billCtrl.setBillPaid(billId: novBill.id, isPaid: false);
      expect(moneyCtrl.currentOverview.unpaidObligationsMinor, 250000);
      expect(billCtrl.allBills.length, 2);

      final result2 = await billCtrl.setBillPaid(
        billId: novBill.id,
        isPaid: true,
      );
      expect(result2?.spawnedNextBill, isNull);
      expect(billCtrl.allBills.length, 2);
      expect(moneyCtrl.currentOverview.unpaidObligationsMinor, 0);

      moneyCtrl.dispose();
      billCtrl.dispose();
    });
  });

  group('Bills & Reminders RLS Ownership & Logout Cache Isolation', () {
    test(
      'denies cross-account mutations and clears private caches on logout',
      () async {
        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 9, 0);
        final InMemoryBillRepository billRepo = InMemoryBillRepository(
          clock: () => fixedNow,
        );
        final InMemoryReminderRepository remRepo = InMemoryReminderRepository(
          clock: () => fixedNow,
        );

        final BillItem userABill = await billRepo.createBill(
          authenticatedUserId: 'usr_a',
          title: 'Private Rent',
          amountMinor: 1200000,
          currency: SupportedCurrency.php,
          dueDate: const KayaDateOnly(2026, 11, 20),
        );
        final ReminderItem userARem = await remRepo.createReminder(
          authenticatedUserId: 'usr_a',
          title: 'Passport Pickup',
          dueDate: const KayaDateOnly(2026, 11, 18),
        );

        // User B cannot fetch, toggle, or delete User A records.
        expect(
          () => billRepo.fetchBills(
            authenticatedUserId: 'usr_b',
            requestedOwnerId: 'usr_a',
          ),
          throwsA(isA<AuthFailure>()),
        );
        expect(
          () => billRepo.setBillPaid(
            authenticatedUserId: 'usr_b',
            billId: userABill.id,
            isPaid: true,
          ),
          throwsA(isA<AuthFailure>()),
        );
        expect(
          () => remRepo.fetchReminders(
            authenticatedUserId: 'usr_b',
            requestedOwnerId: 'usr_a',
          ),
          throwsA(isA<AuthFailure>()),
        );
        expect(
          () => remRepo.deleteReminder(
            authenticatedUserId: 'usr_b',
            reminderId: userARem.id,
          ),
          throwsA(isA<AuthFailure>()),
        );

        final BillController billCtrl = BillController(
          repository: billRepo,
          clock: () => fixedNow,
        );
        final ReminderController remCtrl = ReminderController(
          repository: remRepo,
          clock: () => fixedNow,
        );

        await billCtrl.bindAuthenticatedUser('usr_a');
        await remCtrl.bindAuthenticatedUser('usr_a');
        expect(billCtrl.allBills.length, 1);
        expect(remCtrl.allReminders.length, 1);

        // Logout immediately clears private caches.
        await billCtrl.bindAuthenticatedUser(null);
        await remCtrl.bindAuthenticatedUser(null);
        expect(billCtrl.allBills, isEmpty);
        expect(remCtrl.allReminders, isEmpty);

        // Switching to User B exposes zero User A records.
        await billCtrl.bindAuthenticatedUser('usr_b');
        await remCtrl.bindAuthenticatedUser('usr_b');
        expect(billCtrl.allBills, isEmpty);
        expect(remCtrl.allReminders, isEmpty);

        billCtrl.dispose();
        remCtrl.dispose();
      },
    );
  });
}
