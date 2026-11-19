import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/assistant/application/assistant_context_builder.dart';
import 'package:kaya/features/assistant/application/assistant_controller.dart';
import 'package:kaya/features/assistant/data/local_stub_ai_assistant_gateway.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_models.dart';
import 'package:kaya/features/assistant/domain/ai_context_minimizer.dart';
import 'package:kaya/features/assistant/domain/ai_response_validator.dart';
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
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';

void main() {
  group('Phase 9 AI Context Minimization & Response Validation', () {
    test('excludes financial data, document alerts, notes, IDs, and locations unless explicitly consented', () async {
      final DateTime fixedNow = DateTime.utc(2026, 11, 16, 9, 0);
      const KayaDateOnly today = KayaDateOnly(2026, 11, 16);

      final TaskController taskCtrl = TaskController(
        repository: InMemoryTaskRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_secret_owner',
      );
      final MoneyController moneyCtrl = MoneyController(
        repository: InMemoryMoneyRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_secret_owner',
        initialCurrency: SupportedCurrency.php,
      );
      final BillController billCtrl = BillController(
        repository: InMemoryBillRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_secret_owner',
        initialCurrency: SupportedCurrency.php,
      );
      final LifeVaultController vaultCtrl = LifeVaultController(
        repository: InMemoryLifeVaultRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_secret_owner',
      );

      await taskCtrl.loadTasks();
      await moneyCtrl.loadMoneyData();
      await billCtrl.loadBills();
      await vaultCtrl.loadVault();

      await taskCtrl.createTask(
        title: 'Prepare monthly report',
        notes: 'SECRET_TASK_NOTE_999',
        dueDate: today,
      );
      await moneyCtrl.createTransaction(
        type: TransactionType.income,
        category: MoneyCategory.salary,
        title: 'Private Employer Bonus',
        amountMinor: 5000000,
        transactionDate: today,
      );
      await vaultCtrl.createDocument(
        title: 'Passport',
        category: DocumentCategory.passportVisa,
        physicalLocation: 'Bedroom Safe Box 3',
        notes: 'SECRET_PASSPORT_NUMBER',
        expirationDate: today.addDays(10),
      );

      final AssistantContextBuilder builder = AssistantContextBuilder(
        taskController: taskCtrl,
        moneyController: moneyCtrl,
        billController: billCtrl,
        lifeVaultController: vaultCtrl,
        clock: () => fixedNow,
      );
      final snapshot = builder.build(activeUserId: 'usr_secret_owner');

      // Default consent: financial & document data MUST be excluded.
      final AiMinimizedContextPayload defaultPayload =
          AiContextMinimizer.buildMinimizedPayload(
            snapshot: snapshot,
            consent: const AiConsentSettings(aiEnabled: true),
          );
      expect(defaultPayload.financialSummary, isNull);
      expect(defaultPayload.documentAlerts, isNull);
      final String defaultJsonStr = defaultPayload.toJson().toString();
      expect(defaultJsonStr, isNot(contains('usr_secret_owner')));
      expect(defaultJsonStr, isNot(contains('SECRET_TASK_NOTE_999')));
      expect(defaultJsonStr, isNot(contains('Private Employer Bonus')));
      expect(defaultJsonStr, isNot(contains('Bedroom Safe Box 3')));
      expect(defaultJsonStr, isNot(contains('SECRET_PASSPORT_NUMBER')));

      // Opt-in consent: includes aggregated financial & doc status, STILL strips secrets/locations/transactions.
      final AiMinimizedContextPayload optedInPayload =
          AiContextMinimizer.buildMinimizedPayload(
            snapshot: snapshot,
            consent: const AiConsentSettings(
              aiEnabled: true,
              shareFinancialSummary: true,
              shareDocumentAlerts: true,
            ),
          );
      expect(optedInPayload.financialSummary, isNotNull);
      expect(optedInPayload.documentAlerts, isNotNull);
      final String optedInJsonStr = optedInPayload.toJson().toString();
      expect(optedInJsonStr, contains('₱50,000.00'));
      expect(optedInJsonStr, contains('Passport'));
      expect(optedInJsonStr, isNot(contains('Private Employer Bonus')));
      expect(optedInJsonStr, isNot(contains('Bedroom Safe Box 3')));
      expect(optedInJsonStr, isNot(contains('SECRET_PASSPORT_NUMBER')));

      vaultCtrl.dispose();
      billCtrl.dispose();
      moneyCtrl.dispose();
      taskCtrl.dispose();
    });

    test('validates AI responses and rejects empty or invalid suggestions', () {
      expect(
        AiResponseValidator.validate(const AiGatewayResponse(replyText: '   ')),
        isNull,
      );

      final AiGatewayResponse? validated = AiResponseValidator.validate(
        const AiGatewayResponse(
          replyText: 'Clean reply\x00',
          details: <String>['Valid bullet', '   '],
          suggestedTasks: <AiTaskSuggestion>[
            AiTaskSuggestion(id: '1', title: '   '),
            AiTaskSuggestion(id: '2', title: 'Valid task'),
            AiTaskSuggestion(id: '3', title: 'valid task'), // duplicate
          ],
        ),
      );
      expect(validated, isNotNull);
      expect(validated!.replyText, 'Clean reply');
      expect(validated.details, <String>['Valid bullet']);
      expect(validated.suggestedTasks.length, 1);
      expect(validated.suggestedTasks.single.title, 'Valid task');
    });
  });

  group('Phase 9 Quota, Fallback, Confirmed Task Creation & Logout Reset', () {
    test('enforces daily AI quota, falls back on outage/invalid reply, requires confirmation for tasks, and resets on logout', () async {
      final DateTime fixedNow = DateTime.utc(2026, 11, 16, 10, 0);
      final TaskController taskCtrl = TaskController(
        repository: InMemoryTaskRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_ai',
      );
      await taskCtrl.loadTasks();

      final LocalStubAiAssistantGateway gateway = LocalStubAiAssistantGateway();
      final AssistantController assistantCtrl = AssistantController(
        contextBuilder: AssistantContextBuilder(
          taskController: taskCtrl,
          clock: () => fixedNow,
        ),
        aiGateway: gateway,
        clock: () => fixedNow,
        initialUserId: 'usr_ai',
        dailyAiLimit: 2,
      );

      // AI is OFF by default -> deterministic response, quota stays 0.
      final AssistantMessage offReply = (await assistantCtrl.askSmart(
        'What are my tasks today?',
      ))!;
      expect(offReply.source, AssistantReplySource.deterministic);
      expect(assistantCtrl.usageQuota.usedToday, 0);

      // Enable AI -> planning prompt returns validated suggestions without mutating tasks yet.
      assistantCtrl.updateAiConsent(const AiConsentSettings(aiEnabled: true));
      final AssistantMessage planReply = (await assistantCtrl.askSmart(
        'Help me plan my tasks today.',
      ))!;
      expect(planReply.source, AssistantReplySource.ai);
      expect(planReply.taskSuggestions, isNotEmpty);
      expect(assistantCtrl.usageQuota.usedToday, 1);
      expect(taskCtrl.allTasks, isEmpty); // Not created until confirmed!

      // Confirm first suggestion -> creates real task.
      final bool created = await assistantCtrl.confirmTaskSuggestion(
        messageId: planReply.id,
        suggestionId: planReply.taskSuggestions.first.id,
      );
      expect(created, isTrue);
      expect(taskCtrl.allTasks.length, 1);

      // Simulated outage -> automatic deterministic fallback (does not consume quota).
      gateway.simulateFailure = true;
      final AssistantMessage outageFallback = (await assistantCtrl.askSmart(
        'What are my tasks today?',
      ))!;
      expect(outageFallback.source, AssistantReplySource.deterministicFallback);
      expect(assistantCtrl.usageQuota.usedToday, 1);

      // Simulated invalid response -> automatic deterministic fallback.
      gateway.simulateFailure = false;
      gateway.simulateInvalidResponse = true;
      final AssistantMessage invalidFallback = (await assistantCtrl.askSmart(
        'What are my tasks today?',
      ))!;
      expect(
        invalidFallback.source,
        AssistantReplySource.deterministicFallback,
      );

      // Consume 2nd (final) AI call for the day, then verify 3rd falls back due to quota.
      gateway.simulateInvalidResponse = false;
      final AssistantMessage secondAi = (await assistantCtrl.askSmart(
        'Give me a quick overview.',
      ))!;
      expect(secondAi.source, AssistantReplySource.ai);
      expect(assistantCtrl.usageQuota.isExceeded, isTrue);

      final AssistantMessage quotaFallback = (await assistantCtrl.askSmart(
        'What are my tasks today?',
      ))!;
      expect(quotaFallback.source, AssistantReplySource.deterministicFallback);
      expect(quotaFallback.fallbackNotice, contains('Daily AI limit reached'));

      // Logout clears conversation, AI consent, and quota immediately.
      assistantCtrl.bindAuthenticatedUser(null);
      expect(assistantCtrl.messages, isEmpty);
      expect(assistantCtrl.aiConsent.aiEnabled, isFalse);
      expect(assistantCtrl.usageQuota.usedToday, 0);

      assistantCtrl.dispose();
      taskCtrl.dispose();
    });
  });
}
