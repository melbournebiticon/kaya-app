import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/data/in_memory_bill_repository.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/data/in_memory_life_vault_repository.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/data/in_memory_reminder_repository.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/data/in_memory_life_organization_repository.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Phase 8 Smart Assistant Widget & Failure Recovery Tests', () {
    testWidgets(
      'displays grounded Daily Insights, answers English/Taglish prompts, rejects empty/unsupported prompts, and clears chat',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 980);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 9, 0);
        const KayaDateOnly today = KayaDateOnly(2026, 11, 16);

        final TaskController taskCtrl = TaskController(
          repository: InMemoryTaskRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p8_ui',
        );
        final MoneyController moneyCtrl = MoneyController(
          repository: InMemoryMoneyRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p8_ui',
          initialCurrency: SupportedCurrency.php,
        );
        final BillController billCtrl = BillController(
          repository: InMemoryBillRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p8_ui',
          initialCurrency: SupportedCurrency.php,
        );
        final ReminderController remCtrl = ReminderController(
          repository: InMemoryReminderRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p8_ui',
        );
        final LifeVaultController vaultCtrl = LifeVaultController(
          repository: InMemoryLifeVaultRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p8_ui',
        );
        final LifeOrganizationController orgCtrl = LifeOrganizationController(
          repository: InMemoryLifeOrganizationRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p8_ui',
          initialCurrency: SupportedCurrency.php,
        );

        await taskCtrl.loadTasks();
        await moneyCtrl.loadMoneyData();
        await billCtrl.loadBills();
        await remCtrl.loadReminders();
        await vaultCtrl.loadVault();
        await orgCtrl.loadAll();

        await taskCtrl.createTask(
          title: 'Overdue Audit',
          priority: TaskPriority.high,
          dueDate: today.addDays(-1),
        );
        await taskCtrl.createTask(
          title: 'Daily Standup',
          priority: TaskPriority.medium,
          dueDate: today,
        );
        await moneyCtrl.createTransaction(
          type: TransactionType.income,
          category: MoneyCategory.salary,
          title: 'Payroll',
          amountMinor: 1500000, // ₱15,000.00
          transactionDate: today,
        );
        await moneyCtrl.createTransaction(
          type: TransactionType.expense,
          category: MoneyCategory.food,
          title: 'Groceries',
          amountMinor: 300000, // ₱3,000.00
          transactionDate: today,
        );
        await billCtrl.createBill(
          title: 'Internet Bill',
          amountMinor: 150000, // ₱1,500.00 unpaid
          dueDate: today.addDays(2),
        );
        await vaultCtrl.createDocument(
          title: 'NBI Clearance',
          category: DocumentCategory.governmentId,
          physicalLocation: 'Desk Drawer',
          expirationDate: today.addDays(-2),
        );
        await orgCtrl.createRoutine(
          title: 'Evening Stretch',
          scheduledWeekdays: const <int>{1, 2, 3, 4, 5},
          initialSteps: const <String>['Stretch 10m'],
        );

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            taskController: taskCtrl,
            moneyController: moneyCtrl,
            billController: billCtrl,
            reminderController: remCtrl,
            lifeVaultController: vaultCtrl,
            lifeOrganizationController: orgCtrl,
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Assistant tab.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Assistant'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('KAYA Smart Assistant'), findsOneWidget);
        expect(find.text('Daily Insights'), findsOneWidget);
        // Safe to Spend: 15,000 - 3,000 - 1,500 = 10,500.00.
        expect(find.text('Safe to Spend: ₱10,500.00'), findsOneWidget);

        // Tap suggested prompt chip "Magkano safe to spend ko?".
        final Finder safePromptChip = find.descendant(
          of: find.byKey(
            const ValueKey<String>('assistant_suggested_questions'),
          ),
          matching: find.text('Magkano safe to spend ko?'),
        );
        await tester.ensureVisible(safePromptChip);
        await tester.pumpAndSettle();
        await tester.tap(safePromptChip);
        await tester.pumpAndSettle();
        expect(
          find.text('Ang Safe to Spend mo ngayon ay ₱10,500.00.'),
          findsOneWidget,
        );

        // Submit empty prompt -> inline validation error, no crash.
        await tester.tap(
          find.byKey(const ValueKey<String>('assistant_send_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Please type a question for KAYA.'), findsOneWidget);

        // Ask Taglish overdue tasks query via text input.
        await tester.enterText(
          find.byKey(const ValueKey<String>('assistant_prompt_input')),
          'May overdue tasks ba ako?',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('assistant_send_button')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Overdue Audit'), findsAtLeastNWidgets(1));

        // Ask out-of-scope question -> safe deterministic fallback.
        await tester.enterText(
          find.byKey(const ValueKey<String>('assistant_prompt_input')),
          'What is the weather tomorrow?',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('assistant_send_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Right now I only answer read-only questions'),
          findsOneWidget,
        );

        // Clear conversation resets cleanly.
        final Finder clearBtn = find.byKey(
          const ValueKey<String>('assistant_clear_button'),
        );
        await tester.ensureVisible(clearBtn);
        await tester.pumpAndSettle();
        await tester.tap(clearBtn);
        await tester.pumpAndSettle();
        expect(find.text('No Conversation Active'), findsOneWidget);

        taskCtrl.dispose();
        moneyCtrl.dispose();
        billCtrl.dispose();
        remCtrl.dispose();
        vaultCtrl.dispose();
        orgCtrl.dispose();
      },
    );

    testWidgets(
      'surfaces retrieval error state and recovers cleanly via Retry button',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 980);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 9, 0);
        final InMemoryBillRepository billRepo = InMemoryBillRepository(
          clock: () => fixedNow,
        )..simulateNetworkFailure = true;

        final TaskController taskCtrl = TaskController(
          repository: InMemoryTaskRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p8_retry',
        );
        final MoneyController moneyCtrl = MoneyController(
          repository: InMemoryMoneyRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p8_retry',
        );
        final BillController billCtrl = BillController(
          repository: billRepo,
          clock: () => fixedNow,
          initialUserId: 'usr_p8_retry',
        );

        await taskCtrl.loadTasks();
        await moneyCtrl.loadMoneyData();
        await billCtrl.loadBills();

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            taskController: taskCtrl,
            moneyController: moneyCtrl,
            billController: billCtrl,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Assistant'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Some KAYA data failed to load'), findsOneWidget);
        final Finder retryButton = find.byKey(
          const ValueKey<String>('assistant_retry_data_button'),
        );
        expect(retryButton, findsOneWidget);

        final Finder billsPromptChip = find.descendant(
          of: find.byKey(
            const ValueKey<String>('assistant_suggested_questions'),
          ),
          matching: find.text('What bills are due soon?'),
        );
        await tester.ensureVisible(billsPromptChip);
        await tester.pumpAndSettle();
        await tester.tap(billsPromptChip);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('could not retrieve your Bills'),
          findsOneWidget,
        );

        // Fix network failure and tap Retry.
        billRepo.simulateNetworkFailure = false;
        await tester.ensureVisible(retryButton);
        await tester.pumpAndSettle();
        await tester.tap(retryButton);
        await tester.pumpAndSettle();

        expect(find.text('Some KAYA data failed to load'), findsNothing);
        expect(retryButton, findsNothing);

        taskCtrl.dispose();
        moneyCtrl.dispose();
        billCtrl.dispose();
      },
    );
  });
}
