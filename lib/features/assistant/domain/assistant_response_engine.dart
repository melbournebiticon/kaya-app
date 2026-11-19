import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/assistant/domain/assistant_context_snapshot.dart';
import 'package:kaya/features/assistant/domain/assistant_models.dart';
import 'package:kaya/features/assistant/domain/assistant_urgency_ranker.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';

/// Deterministic reply builder grounded strictly in verified KAYA records.
///
/// Enforces:
/// - Zero fabricated records or statistics.
/// - Reuses [SafeToSpendCalculator] output directly for financial replies.
/// - Explicit separation between empty loaded data and retrieval failures.
abstract final class AssistantResponseEngine {
  static AssistantMessage generateReply({
    required ParsedAssistantQuery parsed,
    required AssistantContextSnapshot snapshot,
    required String messageId,
    required DateTime timestamp,
  }) {
    final bool isTaglish = parsed.language == AssistantLanguage.taglish;

    if (!snapshot.isAuthenticated) {
      return AssistantMessage(
        id: messageId,
        role: AssistantMessageRole.assistant,
        text: isTaglish
            ? 'Hindi naka-sign in ang account. Mag-sign in muna para mabasa ni KAYA ang records mo.'
            : 'No authenticated KAYA account is active. Sign in so I can read your records.',
        intent: parsed.intent,
        status: AssistantReplyStatus.retrievalError,
        failedDomains: const <AssistantSourceDomain>[
          AssistantSourceDomain.system,
        ],
        timestamp: timestamp,
      );
    }

    return switch (parsed.intent) {
      AssistantIntent.tasksToday => _replyTasksToday(
        snapshot: snapshot,
        isTaglish: isTaglish,
        messageId: messageId,
        timestamp: timestamp,
      ),
      AssistantIntent.overdueTasks => _replyOverdueTasks(
        snapshot: snapshot,
        isTaglish: isTaglish,
        messageId: messageId,
        timestamp: timestamp,
      ),
      AssistantIntent.billsDueSoon => _replyBillsDueSoon(
        snapshot: snapshot,
        isTaglish: isTaglish,
        messageId: messageId,
        timestamp: timestamp,
      ),
      AssistantIntent.safeToSpend => _replySafeToSpend(
        snapshot: snapshot,
        isTaglish: isTaglish,
        messageId: messageId,
        timestamp: timestamp,
      ),
      AssistantIntent.expiringDocuments => _replyExpiringDocuments(
        snapshot: snapshot,
        isTaglish: isTaglish,
        messageId: messageId,
        timestamp: timestamp,
      ),
      AssistantIntent.routinesStatus => _replyRoutinesStatus(
        snapshot: snapshot,
        isTaglish: isTaglish,
        messageId: messageId,
        timestamp: timestamp,
      ),
      AssistantIntent.focusToday => _replyFocusToday(
        snapshot: snapshot,
        isTaglish: isTaglish,
        messageId: messageId,
        timestamp: timestamp,
      ),
      AssistantIntent.summarizeDay => _replySummarizeDay(
        snapshot: snapshot,
        isTaglish: isTaglish,
        messageId: messageId,
        timestamp: timestamp,
      ),
      AssistantIntent.unsupported => _replyUnsupported(
        isTaglish: isTaglish,
        messageId: messageId,
        timestamp: timestamp,
      ),
    };
  }

  static AssistantMessage _buildRetrievalFailure({
    required String messageId,
    required DateTime timestamp,
    required AssistantIntent intent,
    required bool isTaglish,
    required List<AssistantSourceDomain> failedDomains,
    String? customDetail,
  }) {
    final String labels = failedDomains
        .map((AssistantSourceDomain d) => d.label)
        .join(', ');
    final String text = isTaglish
        ? 'Hindi ko ma-verify ngayon ang data mula sa $labels dahil nag-fail ang loading. Pindutin ang Retry para subukan ulit.'
        : 'I could not retrieve your $labels right now because loading failed. Please tap Retry before assuming those records are empty.';
    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: text,
      details: customDetail != null && customDetail.trim().isNotEmpty
          ? <String>[customDetail.trim()]
          : const <String>[],
      intent: intent,
      status: AssistantReplyStatus.retrievalError,
      failedDomains: failedDomains,
      timestamp: timestamp,
    );
  }

  static AssistantMessage _replyTasksToday({
    required AssistantContextSnapshot snapshot,
    required bool isTaglish,
    required String messageId,
    required DateTime timestamp,
  }) {
    if (!snapshot.tasks.isReady) {
      return _buildRetrievalFailure(
        messageId: messageId,
        timestamp: timestamp,
        intent: AssistantIntent.tasksToday,
        isTaglish: isTaglish,
        failedDomains: const <AssistantSourceDomain>[
          AssistantSourceDomain.tasks,
        ],
        customDetail: snapshot.tasks.errorMessage,
      );
    }

    final KayaDateOnly today = snapshot.referenceToday;
    final List<TaskItem> todayTasks = snapshot.todayTasks;
    final List<TaskItem> overdueTasks = snapshot.overdueTasks;

    if (todayTasks.isEmpty && overdueTasks.isEmpty) {
      return AssistantMessage(
        id: messageId,
        role: AssistantMessageRole.assistant,
        text: isTaglish
            ? 'Wala kang nakatakdang tasks ngayon (${today.formatReadable()}) at wala ring overdue tasks.'
            : 'You have no tasks due today (${today.formatReadable()}) and no overdue tasks.',
        intent: AssistantIntent.tasksToday,
        status: AssistantReplyStatus.emptyData,
        timestamp: timestamp,
      );
    }

    final List<String> details = <String>[
      for (final TaskItem task in todayTasks.take(6))
        '• Today: ${task.title} (${task.priority.label})',
      for (final TaskItem task in overdueTasks.take(4))
        '• Overdue: ${task.title} (${task.dueStatusLabel(today)}, ${task.priority.label})',
    ];

    final String text;
    if (todayTasks.isEmpty) {
      text = isTaglish
          ? 'Wala kang task na naka-due ngayon, pero may ${overdueTasks.length} overdue task${overdueTasks.length == 1 ? '' : 's'} na kailangan pang tapusin:'
          : 'You have 0 tasks due today, though you still have ${overdueTasks.length} overdue task${overdueTasks.length == 1 ? '' : 's'}:';
    } else if (overdueTasks.isEmpty) {
      text = isTaglish
          ? 'May ${todayTasks.length} task${todayTasks.length == 1 ? '' : 's'} ka ngayon (${today.formatReadable()}):'
          : 'You have ${todayTasks.length} task${todayTasks.length == 1 ? '' : 's'} scheduled for today (${today.formatReadable()}):';
    } else {
      text = isTaglish
          ? 'May ${todayTasks.length} task ka ngayon plus ${overdueTasks.length} overdue na task:'
          : 'You have ${todayTasks.length} task${todayTasks.length == 1 ? '' : 's'} due today and ${overdueTasks.length} overdue:';
    }

    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: text,
      details: details,
      intent: AssistantIntent.tasksToday,
      status: AssistantReplyStatus.answered,
      timestamp: timestamp,
    );
  }

  static AssistantMessage _replyOverdueTasks({
    required AssistantContextSnapshot snapshot,
    required bool isTaglish,
    required String messageId,
    required DateTime timestamp,
  }) {
    if (!snapshot.tasks.isReady) {
      return _buildRetrievalFailure(
        messageId: messageId,
        timestamp: timestamp,
        intent: AssistantIntent.overdueTasks,
        isTaglish: isTaglish,
        failedDomains: const <AssistantSourceDomain>[
          AssistantSourceDomain.tasks,
        ],
        customDetail: snapshot.tasks.errorMessage,
      );
    }

    final KayaDateOnly today = snapshot.referenceToday;
    final List<TaskItem> overdue = snapshot.overdueTasks;

    if (overdue.isEmpty) {
      return AssistantMessage(
        id: messageId,
        role: AssistantMessageRole.assistant,
        text: isTaglish
            ? 'Wala kang overdue tasks sa ngayon. Keep it up!'
            : 'You have no overdue tasks right now.',
        intent: AssistantIntent.overdueTasks,
        status: AssistantReplyStatus.emptyData,
        timestamp: timestamp,
      );
    }

    final List<String> details = <String>[
      for (final TaskItem task in overdue.take(8))
        '• ${task.title} — ${task.dueStatusLabel(today)} (${task.priority.label})',
    ];
    final String text = isTaglish
        ? 'May ${overdue.length} overdue task${overdue.length == 1 ? '' : 's'} ka ngayon:'
        : 'You currently have ${overdue.length} overdue task${overdue.length == 1 ? '' : 's'}:';

    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: text,
      details: details,
      intent: AssistantIntent.overdueTasks,
      status: AssistantReplyStatus.answered,
      timestamp: timestamp,
    );
  }

  static AssistantMessage _replyBillsDueSoon({
    required AssistantContextSnapshot snapshot,
    required bool isTaglish,
    required String messageId,
    required DateTime timestamp,
  }) {
    if (!snapshot.bills.isReady) {
      return _buildRetrievalFailure(
        messageId: messageId,
        timestamp: timestamp,
        intent: AssistantIntent.billsDueSoon,
        isTaglish: isTaglish,
        failedDomains: const <AssistantSourceDomain>[
          AssistantSourceDomain.bills,
        ],
        customDetail: snapshot.bills.errorMessage,
      );
    }

    final KayaDateOnly today = snapshot.referenceToday;
    final List<BillItem> dueSoon = snapshot.dueSoonBills;
    final List<BillItem> allUnpaid = snapshot.unpaidBills;

    if (dueSoon.isEmpty) {
      final int laterCount = allUnpaid.length;
      final String text;
      if (laterCount > 0) {
        text = isTaglish
            ? 'Walang unpaid bills na overdue o due sa loob ng susunod na 7 araw. May $laterCount unpaid bill${laterCount == 1 ? '' : 's'} ka na mas matagal pa ang due date.'
            : 'You have no unpaid bills due within the next 7 days ($laterCount later unpaid bill${laterCount == 1 ? '' : 's'} remain).';
      } else {
        text = isTaglish
            ? 'Wala kang unpaid bills na due soon.'
            : 'You have no unpaid bills due soon.';
      }
      return AssistantMessage(
        id: messageId,
        role: AssistantMessageRole.assistant,
        text: text,
        intent: AssistantIntent.billsDueSoon,
        status: AssistantReplyStatus.emptyData,
        timestamp: timestamp,
      );
    }

    final int sameCurrencyTotalMinor = dueSoon
        .where((BillItem b) => b.currency == snapshot.activeCurrency)
        .fold<int>(0, (int sum, BillItem b) => sum + b.amountMinor);
    final String formattedTotal = MoneyFormatter.formatMinorUnits(
      sameCurrencyTotalMinor,
      snapshot.activeCurrency,
    );

    final List<String> details = <String>[
      for (final BillItem bill in dueSoon.take(8))
        '• ${bill.title} — ${MoneyFormatter.formatMinorUnits(bill.amountMinor, bill.currency)} (${bill.dueStatusLabel(today)})',
    ];

    final String text = isTaglish
        ? 'May ${dueSoon.length} unpaid bill${dueSoon.length == 1 ? '' : 's'} na due o malapit nang mag-due (Total: $formattedTotal):'
        : 'You have ${dueSoon.length} unpaid bill${dueSoon.length == 1 ? '' : 's'} overdue or due within 7 days (Total: $formattedTotal):';

    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: text,
      details: details,
      intent: AssistantIntent.billsDueSoon,
      status: AssistantReplyStatus.answered,
      timestamp: timestamp,
    );
  }

  static AssistantMessage _replySafeToSpend({
    required AssistantContextSnapshot snapshot,
    required bool isTaglish,
    required String messageId,
    required DateTime timestamp,
  }) {
    final List<AssistantSourceDomain> failed = <AssistantSourceDomain>[
      if (!snapshot.moneyOverview.isReady) AssistantSourceDomain.money,
      if (!snapshot.bills.isReady) AssistantSourceDomain.bills,
    ];
    if (failed.isNotEmpty) {
      return _buildRetrievalFailure(
        messageId: messageId,
        timestamp: timestamp,
        intent: AssistantIntent.safeToSpend,
        isTaglish: isTaglish,
        failedDomains: failed,
        customDetail:
            snapshot.moneyOverview.errorMessage ?? snapshot.bills.errorMessage,
      );
    }

    final FinancialOverviewSummary? overview = snapshot.moneyOverview.data;
    if (overview == null || !overview.hasAnyActivity) {
      return AssistantMessage(
        id: messageId,
        role: AssistantMessageRole.assistant,
        text: isTaglish
            ? 'Wala pang recorded income, expenses, monthly budget, o unpaid bills para sa buwang ito. Maglagay muna sa Money tab para makalkula ang Safe to Spend mo.'
            : 'No income, expenses, monthly budget, or unpaid bills are recorded for this month yet. Add records in Money so I can show your Safe to Spend.',
        intent: AssistantIntent.safeToSpend,
        status: AssistantReplyStatus.emptyData,
        timestamp: timestamp,
      );
    }

    final String safeStr = MoneyFormatter.formatMinorUnits(
      overview.safeToSpendMinor,
      overview.currency,
    );
    final String balanceStr = MoneyFormatter.formatMinorUnits(
      overview.availableBalanceMinor,
      overview.currency,
    );
    final String billsStr = MoneyFormatter.formatMinorUnits(
      overview.unpaidObligationsMinor,
      overview.currency,
    );

    final List<String> details = <String>[
      '• Status: ${overview.health.label}',
      '• Available balance: $balanceStr',
      if (overview.remainingBudgetMinor != null)
        '• Remaining budget: ${MoneyFormatter.formatMinorUnits(overview.remainingBudgetMinor!, overview.currency)}',
      '• Reserved for unpaid bills: $billsStr',
    ];

    final String text = isTaglish
        ? 'Ang Safe to Spend mo ngayon ay $safeStr.'
        : 'Your current Safe to Spend is $safeStr.';

    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: text,
      details: details,
      intent: AssistantIntent.safeToSpend,
      status: AssistantReplyStatus.answered,
      timestamp: timestamp,
    );
  }

  static AssistantMessage _replyExpiringDocuments({
    required AssistantContextSnapshot snapshot,
    required bool isTaglish,
    required String messageId,
    required DateTime timestamp,
  }) {
    if (!snapshot.documents.isReady) {
      return _buildRetrievalFailure(
        messageId: messageId,
        timestamp: timestamp,
        intent: AssistantIntent.expiringDocuments,
        isTaglish: isTaglish,
        failedDomains: const <AssistantSourceDomain>[
          AssistantSourceDomain.documents,
        ],
        customDetail: snapshot.documents.errorMessage,
      );
    }

    final KayaDateOnly today = snapshot.referenceToday;
    final List<VaultDocument> attentionDocs = <VaultDocument>[
      ...snapshot.expiredDocuments,
      ...snapshot.expiringSoonDocuments,
    ];

    if (attentionDocs.isEmpty) {
      final int totalDocs = snapshot.documents.data?.length ?? 0;
      final String text = isTaglish
          ? (totalDocs == 0
                ? 'Wala pang nakalagay na documents sa Life Vault mo.'
                : 'Walang expired o malapit mag-expire (within 30 days) sa $totalDocs document${totalDocs == 1 ? '' : 's'} mo sa Life Vault.')
          : (totalDocs == 0
                ? 'You have no documents saved in Life Vault yet.'
                : 'None of your $totalDocs Life Vault document${totalDocs == 1 ? '' : 's'} are expired or expiring within 30 days.');
      return AssistantMessage(
        id: messageId,
        role: AssistantMessageRole.assistant,
        text: text,
        intent: AssistantIntent.expiringDocuments,
        status: AssistantReplyStatus.emptyData,
        timestamp: timestamp,
      );
    }

    final List<String> details = <String>[
      for (final VaultDocument doc in attentionDocs.take(8))
        '• ${doc.title} (${doc.category.label}) — ${doc.expirationStatusLabel(today)}',
    ];

    final String text = isTaglish
        ? 'May ${attentionDocs.length} document${attentionDocs.length == 1 ? '' : 's'} na expired o malapit nang mag-expire sa Life Vault:'
        : 'You have ${attentionDocs.length} Life Vault document${attentionDocs.length == 1 ? '' : 's'} expired or expiring within 30 days:';

    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: text,
      details: details,
      intent: AssistantIntent.expiringDocuments,
      status: AssistantReplyStatus.answered,
      timestamp: timestamp,
    );
  }

  static AssistantMessage _replyRoutinesStatus({
    required AssistantContextSnapshot snapshot,
    required bool isTaglish,
    required String messageId,
    required DateTime timestamp,
  }) {
    if (!snapshot.routines.isReady) {
      return _buildRetrievalFailure(
        messageId: messageId,
        timestamp: timestamp,
        intent: AssistantIntent.routinesStatus,
        isTaglish: isTaglish,
        failedDomains: const <AssistantSourceDomain>[
          AssistantSourceDomain.routines,
        ],
        customDetail: snapshot.routines.errorMessage,
      );
    }

    final KayaDateOnly today = snapshot.referenceToday;
    final List<DailyRoutine> scheduledToday = snapshot.todayScheduledRoutines;
    if (scheduledToday.isEmpty) {
      final int totalRoutines = snapshot.routines.data?.length ?? 0;
      return AssistantMessage(
        id: messageId,
        role: AssistantMessageRole.assistant,
        text: isTaglish
            ? (totalRoutines == 0
                  ? 'Wala ka pang nagawang daily routines.'
                  : 'Walang nakaschedule na routine para sa araw na ito.')
            : (totalRoutines == 0
                  ? 'You have not created any daily routines yet.'
                  : 'You have no routines scheduled for today.'),
        intent: AssistantIntent.routinesStatus,
        status: AssistantReplyStatus.emptyData,
        timestamp: timestamp,
      );
    }

    final int completedCount = scheduledToday
        .where((DailyRoutine r) => r.isCompletedOn(today))
        .length;
    final List<String> details = <String>[
      for (final DailyRoutine r in scheduledToday.take(6))
        '• ${r.title}: ${r.completedStepsCountOn(today)}/${r.steps.length} steps • ${r.currentStreak(today)} day streak',
    ];

    final String text = isTaglish
        ? 'Tapos mo na ang $completedCount sa ${scheduledToday.length} scheduled routines ngayong araw:'
        : 'You have completed $completedCount of ${scheduledToday.length} scheduled routine${scheduledToday.length == 1 ? '' : 's'} today:';

    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: text,
      details: details,
      intent: AssistantIntent.routinesStatus,
      status: AssistantReplyStatus.answered,
      timestamp: timestamp,
    );
  }

  static AssistantMessage _replyFocusToday({
    required AssistantContextSnapshot snapshot,
    required bool isTaglish,
    required String messageId,
    required DateTime timestamp,
  }) {
    final bool allPriorityDomainsFailed =
        snapshot.tasks.isFailed &&
        snapshot.bills.isFailed &&
        snapshot.reminders.isFailed &&
        snapshot.documents.isFailed;
    if (allPriorityDomainsFailed) {
      return _buildRetrievalFailure(
        messageId: messageId,
        timestamp: timestamp,
        intent: AssistantIntent.focusToday,
        isTaglish: isTaglish,
        failedDomains: snapshot.failedDomains,
      );
    }

    final List<AssistantUrgentItem> ranked =
        AssistantUrgencyRanker.rankUrgentItems(snapshot);
    final List<AssistantSourceDomain> failed = snapshot.failedDomains;

    if (ranked.isEmpty && failed.isEmpty) {
      return AssistantMessage(
        id: messageId,
        role: AssistantMessageRole.assistant,
        text: isTaglish
            ? 'Walang urgent items ngayon sa tasks, bills, reminders, o documents mo. Magandang araw para magplano!'
            : 'Nothing urgent is competing for your attention right now across tasks, bills, reminders, or documents.',
        intent: AssistantIntent.focusToday,
        status: AssistantReplyStatus.emptyData,
        timestamp: timestamp,
      );
    }

    final List<String> details = <String>[
      for (int i = 0; i < ranked.length && i < 5; i++)
        '${i + 1}. ${ranked[i].title} (${ranked[i].domain.label} — ${ranked[i].subtitle})',
      if (failed.isNotEmpty)
        '• Note: Could not load ${failed.map((AssistantSourceDomain d) => d.label).join(', ')}.',
    ];

    final String text;
    if (ranked.isEmpty) {
      text = isTaglish
          ? 'May ilang records na hindi na-load kaya hindi kumpleto ang priority ranking:'
          : 'Some KAYA domains failed to load, so focus priorities may be incomplete:';
    } else {
      final AssistantUrgentItem top = ranked.first;
      text = isTaglish
          ? 'Pinaka-dapat mong unahin ngayon: ${top.title} (${top.subtitle}).'
          : 'Your top focus right now is: ${top.title} (${top.subtitle}).';
    }

    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: text,
      details: details,
      intent: AssistantIntent.focusToday,
      status: ranked.isEmpty
          ? AssistantReplyStatus.retrievalError
          : AssistantReplyStatus.answered,
      failedDomains: failed,
      timestamp: timestamp,
    );
  }

  static AssistantMessage _replySummarizeDay({
    required AssistantContextSnapshot snapshot,
    required bool isTaglish,
    required String messageId,
    required DateTime timestamp,
  }) {
    final List<AssistantSourceDomain> failed = snapshot.failedDomains;
    final bool allCoreFailed =
        snapshot.tasks.isFailed &&
        snapshot.moneyOverview.isFailed &&
        snapshot.bills.isFailed &&
        snapshot.reminders.isFailed &&
        snapshot.documents.isFailed &&
        snapshot.routines.isFailed;

    if (allCoreFailed) {
      return _buildRetrievalFailure(
        messageId: messageId,
        timestamp: timestamp,
        intent: AssistantIntent.summarizeDay,
        isTaglish: isTaglish,
        failedDomains: failed,
      );
    }

    final KayaDateOnly today = snapshot.referenceToday;
    final List<String> lines = <String>[];

    if (snapshot.tasks.isFailed) {
      lines.add(
        '• Tasks: Unable to load (${snapshot.tasks.errorMessage ?? 'failed'}).',
      );
    } else {
      lines.add(
        '• Tasks: ${snapshot.todayTasks.length} due today, ${snapshot.overdueTasks.length} overdue.',
      );
    }

    if (snapshot.bills.isFailed) {
      lines.add(
        '• Bills: Unable to load (${snapshot.bills.errorMessage ?? 'failed'}).',
      );
    } else {
      lines.add(
        '• Bills: ${snapshot.dueSoonBills.length} due soon (${snapshot.overdueBills.length} overdue).',
      );
    }

    if (snapshot.moneyOverview.isFailed || snapshot.bills.isFailed) {
      lines.add('• Safe to Spend: Unavailable until Money and Bills load.');
    } else {
      final FinancialOverviewSummary? overview = snapshot.moneyOverview.data;
      if (overview != null && overview.hasAnyActivity) {
        lines.add(
          '• Safe to Spend: ${MoneyFormatter.formatMinorUnits(overview.safeToSpendMinor, overview.currency)} (${overview.health.label}).',
        );
      } else {
        lines.add('• Safe to Spend: No monthly money activity yet.');
      }
    }

    if (snapshot.documents.isFailed) {
      lines.add('• Documents: Unable to load.');
    } else {
      final int docAlertCount =
          snapshot.expiredDocuments.length +
          snapshot.expiringSoonDocuments.length;
      lines.add(
        docAlertCount > 0
            ? '• Documents: $docAlertCount need attention (${snapshot.expiredDocuments.length} expired, ${snapshot.expiringSoonDocuments.length} expiring soon).'
            : '• Documents: No expired or expiring-soon records.',
      );
    }

    if (snapshot.routines.isFailed) {
      lines.add('• Routines: Unable to load.');
    } else {
      final int scheduled = snapshot.todayScheduledRoutines.length;
      final int done = snapshot.todayScheduledRoutines
          .where((DailyRoutine r) => r.isCompletedOn(today))
          .length;
      lines.add(
        scheduled > 0
            ? '• Routines: $done/$scheduled completed today.'
            : '• Routines: None scheduled today.',
      );
    }

    final List<AssistantUrgentItem> ranked =
        AssistantUrgencyRanker.rankUrgentItems(snapshot);
    if (ranked.isNotEmpty) {
      lines.add(
        '• Top focus: ${ranked.first.title} (${ranked.first.domain.label}).',
      );
    }

    final bool allEmptyNoFailure =
        failed.isEmpty &&
        ranked.isEmpty &&
        snapshot.todayScheduledRoutines.isEmpty &&
        !(snapshot.moneyOverview.data?.hasAnyActivity ?? false);

    final String header = isTaglish
        ? 'Narito ang buod ng araw mo para sa ${today.formatReadable()}:'
        : 'Here is your KAYA summary for ${today.formatReadable()}:';

    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: header,
      details: lines,
      intent: AssistantIntent.summarizeDay,
      status: allEmptyNoFailure
          ? AssistantReplyStatus.emptyData
          : AssistantReplyStatus.answered,
      failedDomains: failed,
      timestamp: timestamp,
    );
  }

  static AssistantMessage _replyUnsupported({
    required bool isTaglish,
    required String messageId,
    required DateTime timestamp,
  }) {
    final String text = isTaglish
        ? 'Sa Phase 8 na ito, mga read-only na tanong lang tungkol sa totoong KAYA records mo ang kaya kong sagutin (walang hula o automatic record edits).'
        : 'Right now I only answer read-only questions grounded in your real KAYA records (no outside trivia or automatic record edits).';
    const List<String> examples = <String>[
      '• "What are my tasks today?" / "Ano tasks ko ngayon?"',
      '• "May overdue tasks ba ako?"',
      '• "What bills are due soon?"',
      '• "Magkano safe to spend ko?"',
      '• "Are my documents expiring?"',
      '• "What should I focus on today?" / "Summarize my day."',
    ];
    return AssistantMessage(
      id: messageId,
      role: AssistantMessageRole.assistant,
      text: text,
      details: examples,
      intent: AssistantIntent.unsupported,
      status: AssistantReplyStatus.unsupported,
      timestamp: timestamp,
    );
  }
}
