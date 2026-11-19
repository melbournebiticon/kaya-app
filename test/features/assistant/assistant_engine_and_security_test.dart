import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/assistant/application/assistant_context_builder.dart';
import 'package:kaya/features/assistant/application/assistant_controller.dart';
import 'package:kaya/features/assistant/domain/assistant_intent_parser.dart';
import 'package:kaya/features/assistant/domain/assistant_models.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/data/in_memory_bill_repository.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/data/in_memory_life_vault_repository.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/data/in_memory_reminder_repository.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/data/in_memory_life_organization_repository.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';

void main() {
  group('AssistantIntentParser (English, Taglish & Read-Only Guard)', () {
    test('parses all Phase 8 blueprint queries into deterministic intents and languages', () {
      const Map<String, (AssistantIntent, AssistantLanguage)> expected =
          <String, (AssistantIntent, AssistantLanguage)>{
            'What are my tasks today?': (
              AssistantIntent.tasksToday,
              AssistantLanguage.english,
            ),
            'Ano tasks ko ngayon?': (
              AssistantIntent.tasksToday,
              AssistantLanguage.taglish,
            ),
            'May overdue tasks ba ako?': (
              AssistantIntent.overdueTasks,
              AssistantLanguage.taglish,
            ),
            'What bills are due soon?': (
              AssistantIntent.billsDueSoon,
              AssistantLanguage.english,
            ),
            'Magkano safe to spend ko?': (
              AssistantIntent.safeToSpend,
              AssistantLanguage.taglish,
            ),
            'Are my documents expiring?': (
              AssistantIntent.expiringDocuments,
              AssistantLanguage.english,
            ),
            'What should I focus on today?': (
              AssistantIntent.focusToday,
              AssistantLanguage.english,
            ),
            'Summarize my day.': (
              AssistantIntent.summarizeDay,
              AssistantLanguage.english,
            ),
            'Am I keeping up with my routines?': (
              AssistantIntent.routinesStatus,
              AssistantLanguage.english,
            ),
            'Ano gagawin ko ngayon?': (
              AssistantIntent.tasksToday,
              AssistantLanguage.taglish,
            ),
          };

      expected.forEach((
        String query,
        (AssistantIntent, AssistantLanguage) exp,
      ) {
        final ParsedAssistantQuery parsed = AssistantIntentParser.parse(query);
        expect(parsed.intent, exp.$1, reason: 'Intent mismatch for "$query"');
        expect(
          parsed.language,
          exp.$2,
          reason: 'Language mismatch for "$query"',
        );
      });
    });

    test(
      'routes mutation commands and out-of-scope prompts to unsupported',
      () {
        final List<String> blockedOrUnsupported = <String>[
          'Add expense 500 for lunch',
          'Delete my overdue task',
          'Pay my Meralco bill now',
          'Create a routine called Stretch',
          'What is the weather in Manila tomorrow?',
          'Tell me a joke about cats',
        ];

        for (final String prompt in blockedOrUnsupported) {
          final ParsedAssistantQuery parsed = AssistantIntentParser.parse(
            prompt,
          );
          expect(
            parsed.intent,
            AssistantIntent.unsupported,
            reason: 'Should safely reject "$prompt" as unsupported',
          );
        }
      },
    );
  });

  group('AssistantResponseEngine & Urgency Ranking (Real KAYA Data)', () {
    test('grounds all replies in real records, reuses SafeToSpendCalculator, and never exposes vault secrets', () async {
      final DateTime fixedNow = DateTime.utc(2026, 11, 16, 9, 0);
      const KayaDateOnly today = KayaDateOnly(2026, 11, 16);

      final TaskController taskCtrl = TaskController(
        repository: InMemoryTaskRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_a',
      );
      final MoneyController moneyCtrl = MoneyController(
        repository: InMemoryMoneyRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_a',
        initialCurrency: SupportedCurrency.php,
      );
      final BillController billCtrl = BillController(
        repository: InMemoryBillRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_a',
        initialCurrency: SupportedCurrency.php,
      );
      final ReminderController remCtrl = ReminderController(
        repository: InMemoryReminderRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_a',
      );
      final LifeVaultController vaultCtrl = LifeVaultController(
        repository: InMemoryLifeVaultRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_a',
      );
      final LifeOrganizationController orgCtrl = LifeOrganizationController(
        repository: InMemoryLifeOrganizationRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_a',
        initialCurrency: SupportedCurrency.php,
      );

      moneyCtrl.bindUnpaidObligationsSource(
        resolver: (int y, int m, SupportedCurrency c) => billCtrl
            .unpaidObligationsMinorForPeriod(year: y, month: m, currency: c),
        listenable: billCtrl,
      );

      await taskCtrl.loadTasks();
      await moneyCtrl.loadMoneyData();
      await billCtrl.loadBills();
      await remCtrl.loadReminders();
      await vaultCtrl.loadVault();
      await orgCtrl.loadAll();

      // Seed real data across domains.
      await taskCtrl.createTask(
        title: 'Submit Q4 tax',
        priority: TaskPriority.urgent,
        dueDate: today.addDays(-2),
      );
      await taskCtrl.createTask(
        title: 'Prepare groceries',
        priority: TaskPriority.high,
        dueDate: today,
      );

      await moneyCtrl.createTransaction(
        type: TransactionType.income,
        category: MoneyCategory.salary,
        title: 'Mid-month payroll',
        amountMinor: 2000000, // ₱20,000.00
        transactionDate: today,
      );
      await moneyCtrl.createTransaction(
        type: TransactionType.expense,
        category: MoneyCategory.food,
        title: 'Team lunch',
        amountMinor: 400000, // ₱4,000.00
        transactionDate: today,
      );
      await moneyCtrl.saveMonthlyBudget(
        overallLimitMinor: 1200000,
      ); // ₱12,000.00

      await billCtrl.createBill(
        title: 'Meralco Bill',
        amountMinor: 250000, // ₱2,500.00 unpaid due in 2 days
        dueDate: today.addDays(2),
      );
      await billCtrl.createBill(
        title: 'Water Utility',
        amountMinor: 60000, // ₱600.00 paid -> excluded
        dueDate: today.addDays(-1),
      );
      final String waterBillId = billCtrl.allBills
          .firstWhere((b) => b.title == 'Water Utility')
          .id;
      await billCtrl.setBillPaid(billId: waterBillId, isPaid: true);

      await vaultCtrl.createDocument(
        title: 'Driver License',
        category: DocumentCategory.governmentId,
        physicalLocation: 'Wallet',
        notes: 'TOP_SECRET_ID_123',
        expirationDate: today.addDays(-6),
      );
      await vaultCtrl.createDocument(
        title: 'Passport',
        category: DocumentCategory.passportVisa,
        physicalLocation: 'Home Safe',
        expirationDate: today.addDays(15),
      );

      await orgCtrl.createRoutine(
        title: 'Morning Reset',
        scheduledWeekdays: const <int>{1, 2, 3, 4, 5},
        initialSteps: const <String>['Drink water'],
      );

      final AssistantController assistantCtrl = AssistantController(
        contextBuilder: AssistantContextBuilder(
          taskController: taskCtrl,
          moneyController: moneyCtrl,
          billController: billCtrl,
          reminderController: remCtrl,
          lifeVaultController: vaultCtrl,
          lifeOrganizationController: orgCtrl,
          clock: () => fixedNow,
        ),
        clock: () => fixedNow,
        initialUserId: 'usr_a',
      );

      // Expected Safe to Spend: min(1600000 cash, 800000 rem budget) - 250000 = 550000 (₱5,500.00).
      final String expectedSafe = MoneyFormatter.formatMinorUnits(
        moneyCtrl.currentOverview.safeToSpendMinor,
        SupportedCurrency.php,
      );
      expect(expectedSafe, '₱5,500.00');

      final AssistantMessage safeReply = assistantCtrl.ask(
        'Magkano safe to spend ko?',
      )!;
      expect(safeReply.status, AssistantReplyStatus.answered);
      expect(safeReply.text, contains('₱5,500.00'));
      expect(safeReply.details.join('\n'), contains('₱2,500.00'));

      final AssistantMessage billsReply = assistantCtrl.ask(
        'What bills are due soon?',
      )!;
      expect(billsReply.status, AssistantReplyStatus.answered);
      expect(billsReply.details.join('\n'), contains('Meralco Bill'));
      expect(billsReply.details.join('\n'), isNot(contains('Water Utility')));

      final AssistantMessage overdueReply = assistantCtrl.ask(
        'May overdue tasks ba ako?',
      )!;
      expect(overdueReply.status, AssistantReplyStatus.answered);
      expect(overdueReply.details.join('\n'), contains('Submit Q4 tax'));

      final AssistantMessage docsReply = assistantCtrl.ask(
        'Are my documents expiring?',
      )!;
      expect(docsReply.status, AssistantReplyStatus.answered);
      expect(docsReply.details.join('\n'), contains('Driver License'));
      expect(docsReply.details.join('\n'), contains('Passport'));
      expect(
        docsReply.details.join('\n'),
        isNot(contains('TOP_SECRET_ID_123')),
      );

      final AssistantMessage routinesReply = assistantCtrl.ask(
        'Am I keeping up with my routines?',
      )!;
      expect(routinesReply.status, AssistantReplyStatus.answered);
      expect(routinesReply.details.join('\n'), contains('Morning Reset'));

      final AssistantMessage focusReply = assistantCtrl.ask(
        'What should I focus on today?',
      )!;
      expect(focusReply.status, AssistantReplyStatus.answered);
      // Expired document outranks overdue task/upcoming bill cleanly.
      expect(focusReply.text, contains('Driver License'));

      final AssistantMessage summaryReply = assistantCtrl.ask(
        'Summarize my day.',
      )!;
      expect(summaryReply.status, AssistantReplyStatus.answered);
      expect(
        summaryReply.details.join('\n'),
        contains('1 due today, 1 overdue'),
      );
      expect(summaryReply.details.join('\n'), contains('₱5,500.00'));

      // Verify toString redaction across message & context snapshot.
      expect(safeReply.toString(), isNot(contains('5,500')));
      expect(
        assistantCtrl.currentSnapshot.toString(),
        isNot(contains('Driver License')),
      );

      assistantCtrl.dispose();
      orgCtrl.dispose();
      vaultCtrl.dispose();
      remCtrl.dispose();
      billCtrl.dispose();
      moneyCtrl.dispose();
      taskCtrl.dispose();
    });
  });

  group('Retrieval Failure vs Empty Data & Account Isolation', () {
    test(
      'separates failed queries from empty records and recovers after retry',
      () async {
        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 10, 0);
        final InMemoryTaskRepository taskRepo = InMemoryTaskRepository(
          clock: () => fixedNow,
        )..simulateNetworkFailure = true;
        final InMemoryBillRepository billRepo = InMemoryBillRepository(
          clock: () => fixedNow,
        )..simulateNetworkFailure = true;

        final TaskController taskCtrl = TaskController(
          repository: taskRepo,
          clock: () => fixedNow,
          initialUserId: 'usr_err',
        );
        final MoneyController moneyCtrl = MoneyController(
          repository: InMemoryMoneyRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_err',
        );
        final BillController billCtrl = BillController(
          repository: billRepo,
          clock: () => fixedNow,
          initialUserId: 'usr_err',
        );
        final LifeVaultController vaultCtrl = LifeVaultController(
          repository: InMemoryLifeVaultRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_err',
        );

        await taskCtrl.loadTasks();
        await moneyCtrl.loadMoneyData();
        await billCtrl.loadBills();
        await vaultCtrl.loadVault();

        final AssistantController assistantCtrl = AssistantController(
          contextBuilder: AssistantContextBuilder(
            taskController: taskCtrl,
            moneyController: moneyCtrl,
            billController: billCtrl,
            lifeVaultController: vaultCtrl,
            clock: () => fixedNow,
          ),
          clock: () => fixedNow,
          initialUserId: 'usr_err',
        );

        final AssistantMessage taskErr = assistantCtrl.ask(
          'May overdue tasks ba ako?',
        )!;
        expect(taskErr.status, AssistantReplyStatus.retrievalError);
        expect(taskErr.failedDomains, contains(AssistantSourceDomain.tasks));

        // Safe to Spend also fails closed when Bills failed (since bills deduct obligations).
        final AssistantMessage safeErr = assistantCtrl.ask(
          'Magkano safe to spend ko?',
        )!;
        expect(safeErr.status, AssistantReplyStatus.retrievalError);
        expect(safeErr.failedDomains, contains(AssistantSourceDomain.bills));

        // Healthy empty Vault still reports emptyData cleanly.
        final AssistantMessage emptyDocs = assistantCtrl.ask(
          'Are my documents expiring?',
        )!;
        expect(emptyDocs.status, AssistantReplyStatus.emptyData);

        // Retry after clearing failure switches to emptyData cleanly.
        taskRepo.simulateNetworkFailure = false;
        billRepo.simulateNetworkFailure = false;
        await assistantCtrl.retryFailedData();

        final AssistantMessage taskRecovered = assistantCtrl.ask(
          'May overdue tasks ba ako?',
        )!;
        expect(taskRecovered.status, AssistantReplyStatus.emptyData);

        assistantCtrl.dispose();
        vaultCtrl.dispose();
        billCtrl.dispose();
        moneyCtrl.dispose();
        taskCtrl.dispose();
      },
    );

    test('clears conversation on logout/account switch and fails closed on mismatched owner', () async {
      final DateTime fixedNow = DateTime.utc(2026, 11, 16, 10, 0);
      final TaskController taskCtrl = TaskController(
        repository: InMemoryTaskRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_a',
      );
      await taskCtrl.loadTasks();
      await taskCtrl.createTask(
        title: 'User A Confidential Filing',
        dueDate: const KayaDateOnly(2026, 11, 16),
      );

      final AssistantController assistantCtrl = AssistantController(
        contextBuilder: AssistantContextBuilder(
          taskController: taskCtrl,
          clock: () => fixedNow,
        ),
        clock: () => fixedNow,
        initialUserId: 'usr_a',
      );

      final AssistantMessage userAReply = assistantCtrl.ask(
        'What are my tasks today?',
      )!;
      expect(userAReply.status, AssistantReplyStatus.answered);
      expect(
        userAReply.details.join('\n'),
        contains('User A Confidential Filing'),
      );
      expect(assistantCtrl.messages.length, 2);

      // Logout wipes conversation immediately and fails closed on query.
      assistantCtrl.bindAuthenticatedUser(null);
      expect(assistantCtrl.messages, isEmpty);

      final AssistantMessage signedOutReply = assistantCtrl.ask(
        'What are my tasks today?',
      )!;
      expect(signedOutReply.status, AssistantReplyStatus.retrievalError);

      // Switching to User B while taskCtrl still holds User A fails closed without leaking!
      assistantCtrl.bindAuthenticatedUser('usr_b');
      expect(assistantCtrl.messages, isEmpty);
      expect(assistantCtrl.currentSnapshot.tasks.isUnauthenticated, isTrue);

      final AssistantMessage userBReply = assistantCtrl.ask(
        'What are my tasks today?',
      )!;
      expect(userBReply.status, AssistantReplyStatus.retrievalError);
      expect(
        userBReply.details.join('\n'),
        isNot(contains('User A Confidential Filing')),
      );

      assistantCtrl.dispose();
      taskCtrl.dispose();
    });
  });
}
