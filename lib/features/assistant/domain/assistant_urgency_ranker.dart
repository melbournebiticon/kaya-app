import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/assistant/domain/assistant_context_snapshot.dart';
import 'package:kaya/features/assistant/domain/assistant_models.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';

/// Deterministic cross-domain urgency ranking and daily insights generator.
///
/// Only evaluates loaded ([DomainReadState.isReady]) domains and never invents
/// missing data.
abstract final class AssistantUrgencyRanker {
  static int _taskPriorityBoost(TaskPriority priority) => switch (priority) {
    TaskPriority.urgent => 60,
    TaskPriority.high => 40,
    TaskPriority.medium => 20,
    TaskPriority.low => 0,
  };

  /// Produces a deterministic priority-ordered list of urgent items across all
  /// loaded KAYA domains for [snapshot].
  static List<AssistantUrgentItem> rankUrgentItems(
    AssistantContextSnapshot snapshot,
  ) {
    if (!snapshot.isAuthenticated) {
      return const <AssistantUrgentItem>[];
    }

    final KayaDateOnly today = snapshot.referenceToday;
    final List<AssistantUrgentItem> ranked = <AssistantUrgentItem>[];

    // 1. Expired and expiring-soon documents.
    if (snapshot.documents.isReady) {
      for (final VaultDocument doc in snapshot.expiredDocuments) {
        final int overdueDays = doc.expirationDate != null
            ? (-doc.expirationDate!.daysDifferenceFrom(today)).clamp(0, 90)
            : 0;
        ranked.add(
          AssistantUrgentItem(
            id: 'doc_${doc.id}',
            title: doc.title,
            subtitle:
                '${doc.category.label} • ${doc.expirationStatusLabel(today)}',
            domain: AssistantSourceDomain.documents,
            urgency: AssistantUrgencyLevel.critical,
            urgencyScore: 1000 + overdueDays,
          ),
        );
      }

      for (final VaultDocument doc in snapshot.expiringSoonDocuments) {
        final int daysRemaining = doc.expirationDate != null
            ? doc.expirationDate!.daysDifferenceFrom(today).clamp(0, 30)
            : 30;
        final bool withinWeek = daysRemaining <= 7;
        ranked.add(
          AssistantUrgentItem(
            id: 'doc_${doc.id}',
            title: doc.title,
            subtitle:
                '${doc.category.label} • ${doc.expirationStatusLabel(today)}',
            domain: AssistantSourceDomain.documents,
            urgency: withinWeek
                ? AssistantUrgencyLevel.high
                : AssistantUrgencyLevel.medium,
            urgencyScore: withinWeek
                ? 650 - daysRemaining
                : 520 - daysRemaining,
          ),
        );
      }
    }

    // 2. Unpaid bills (overdue, due today, due within 7 days).
    if (snapshot.bills.isReady) {
      for (final BillItem bill in snapshot.dueSoonBills) {
        final int deltaDays = bill.dueDate.daysDifferenceFrom(today);
        final String formattedAmount = MoneyFormatter.formatMinorUnits(
          bill.amountMinor,
          bill.currency,
        );
        if (deltaDays < 0) {
          ranked.add(
            AssistantUrgentItem(
              id: 'bill_${bill.id}',
              title: bill.title,
              subtitle: '$formattedAmount • ${bill.dueStatusLabel(today)}',
              domain: AssistantSourceDomain.bills,
              urgency: AssistantUrgencyLevel.critical,
              urgencyScore: 950 + (-deltaDays).clamp(0, 90),
            ),
          );
        } else if (deltaDays == 0) {
          ranked.add(
            AssistantUrgentItem(
              id: 'bill_${bill.id}',
              title: bill.title,
              subtitle: '$formattedAmount • ${bill.dueStatusLabel(today)}',
              domain: AssistantSourceDomain.bills,
              urgency: AssistantUrgencyLevel.high,
              urgencyScore: 780,
            ),
          );
        } else {
          ranked.add(
            AssistantUrgentItem(
              id: 'bill_${bill.id}',
              title: bill.title,
              subtitle: '$formattedAmount • ${bill.dueStatusLabel(today)}',
              domain: AssistantSourceDomain.bills,
              urgency: AssistantUrgencyLevel.medium,
              urgencyScore: 600 - (deltaDays * 10),
            ),
          );
        }
      }
    }

    // 3. Tasks (overdue, due today, high/urgent priority backlog).
    if (snapshot.tasks.isReady) {
      for (final TaskItem task in snapshot.overdueTasks) {
        final int overdueDays = task.dueDate != null
            ? (-task.dueDate!.daysDifferenceFrom(today)).clamp(0, 60)
            : 0;
        ranked.add(
          AssistantUrgentItem(
            id: 'task_${task.id}',
            title: task.title,
            subtitle: '${task.priority.label} • ${task.dueStatusLabel(today)}',
            domain: AssistantSourceDomain.tasks,
            urgency: AssistantUrgencyLevel.critical,
            urgencyScore: 880 + _taskPriorityBoost(task.priority) + overdueDays,
          ),
        );
      }

      for (final TaskItem task in snapshot.todayTasks) {
        final bool isHighOrUrgent =
            task.priority == TaskPriority.high ||
            task.priority == TaskPriority.urgent;
        ranked.add(
          AssistantUrgentItem(
            id: 'task_${task.id}',
            title: task.title,
            subtitle: '${task.priority.label} • ${task.dueStatusLabel(today)}',
            domain: AssistantSourceDomain.tasks,
            urgency: isHighOrUrgent
                ? AssistantUrgencyLevel.high
                : AssistantUrgencyLevel.medium,
            urgencyScore: 720 + _taskPriorityBoost(task.priority),
          ),
        );
      }

      for (final TaskItem task in snapshot.activeTasks) {
        if (task.isOverdue(today) || task.isDueToday(today)) {
          continue;
        }
        if (task.priority == TaskPriority.high ||
            task.priority == TaskPriority.urgent) {
          ranked.add(
            AssistantUrgentItem(
              id: 'task_${task.id}',
              title: task.title,
              subtitle:
                  '${task.priority.label} • ${task.dueStatusLabel(today)}',
              domain: AssistantSourceDomain.tasks,
              urgency: AssistantUrgencyLevel.low,
              urgencyScore: 350 + _taskPriorityBoost(task.priority),
            ),
          );
        }
      }
    }

    // 4. Critical Safe to Spend cushion warning (only when both Money and Bills are ready).
    if (snapshot.moneyOverview.isReady && snapshot.bills.isReady) {
      final FinancialOverviewSummary? overview = snapshot.moneyOverview.data;
      if (overview != null &&
          overview.hasAnyActivity &&
          overview.safeToSpendMinor <= 0) {
        final String formattedSafe = MoneyFormatter.formatMinorUnits(
          overview.safeToSpendMinor,
          overview.currency,
        );
        ranked.add(
          AssistantUrgentItem(
            id: 'money_critical_safe_to_spend',
            title: 'Review Safe to Spend cushion',
            subtitle: 'Current Safe to Spend: $formattedSafe',
            domain: AssistantSourceDomain.money,
            urgency: AssistantUrgencyLevel.critical,
            urgencyScore: 860,
          ),
        );
      }
    }

    // 5. Overdue and today reminders.
    if (snapshot.reminders.isReady) {
      for (final ReminderItem rem in snapshot.overdueReminders) {
        final int overdueDays = (-rem.dueDate.daysDifferenceFrom(
          today,
        )).clamp(0, 60);
        ranked.add(
          AssistantUrgentItem(
            id: 'rem_${rem.id}',
            title: rem.title,
            subtitle: 'Reminder • ${rem.dueStatusLabel(today)}',
            domain: AssistantSourceDomain.reminders,
            urgency: AssistantUrgencyLevel.high,
            urgencyScore: 840 + overdueDays,
          ),
        );
      }
      for (final ReminderItem rem in snapshot.todayReminders) {
        ranked.add(
          AssistantUrgentItem(
            id: 'rem_${rem.id}',
            title: rem.title,
            subtitle: 'Reminder • ${rem.dueStatusLabel(today)}',
            domain: AssistantSourceDomain.reminders,
            urgency: AssistantUrgencyLevel.medium,
            urgencyScore: 680,
          ),
        );
      }
    }

    // 6. Incomplete routines scheduled today.
    if (snapshot.routines.isReady) {
      for (final DailyRoutine routine in snapshot.incompleteTodayRoutines) {
        final int doneSteps = routine.completedStepsCountOn(today);
        final int totalSteps = routine.steps.length;
        ranked.add(
          AssistantUrgentItem(
            id: 'routine_${routine.id}',
            title: routine.title,
            subtitle: totalSteps == 0
                ? 'Scheduled today'
                : '$doneSteps/$totalSteps steps done today',
            domain: AssistantSourceDomain.routines,
            urgency: AssistantUrgencyLevel.low,
            urgencyScore: 450,
          ),
        );
      }
    }

    ranked.sort((AssistantUrgentItem a, AssistantUrgentItem b) {
      final int scoreCmp = b.urgencyScore.compareTo(a.urgencyScore);
      if (scoreCmp != 0) {
        return scoreCmp;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return List<AssistantUrgentItem>.unmodifiable(ranked);
  }

  /// Generates up to 4 grounded daily insights from [snapshot].
  static List<AssistantDailyInsight> buildDailyInsights(
    AssistantContextSnapshot snapshot,
  ) {
    final List<AssistantDailyInsight> insights = <AssistantDailyInsight>[];

    if (!snapshot.isAuthenticated) {
      insights.add(
        const AssistantDailyInsight(
          id: 'insight_unauthenticated',
          title: 'Sign in required',
          detail: 'Sign in to your KAYA account so Assistant can read your personal records.',
          tone: AssistantInsightTone.info,
          domain: AssistantSourceDomain.system,
          followUpPrompt: 'Summarize my day.',
        ),
      );
      return List<AssistantDailyInsight>.unmodifiable(insights);
    }

    if (snapshot.hasAnyFailure) {
      final String failedList = snapshot.failedDomains
          .map((AssistantSourceDomain d) => d.label)
          .join(', ');
      insights.add(
        AssistantDailyInsight(
          id: 'insight_retrieval_failure',
          title: 'Some KAYA data failed to load',
          detail:
              'Could not load: $failedList. Retry before relying on totals.',
          tone: AssistantInsightTone.critical,
          domain: AssistantSourceDomain.system,
          followUpPrompt: 'Summarize my day.',
        ),
      );
    }

    final List<AssistantUrgentItem> ranked = rankUrgentItems(snapshot);
    if (ranked.isNotEmpty) {
      final AssistantUrgentItem top = ranked.first;
      insights.add(
        AssistantDailyInsight(
          id: 'insight_top_focus',
          title: 'Top focus: ${top.title}',
          detail: '${top.domain.label} • ${top.subtitle}',
          tone: top.urgency == AssistantUrgencyLevel.critical
              ? AssistantInsightTone.critical
              : (top.urgency == AssistantUrgencyLevel.high
                    ? AssistantInsightTone.warning
                    : AssistantInsightTone.info),
          domain: top.domain,
          followUpPrompt: 'What should I focus on today?',
        ),
      );
    }

    if (snapshot.moneyOverview.isReady && snapshot.bills.isReady) {
      final FinancialOverviewSummary? overview = snapshot.moneyOverview.data;
      if (overview != null && overview.hasAnyActivity) {
        final String formattedSafe = MoneyFormatter.formatMinorUnits(
          overview.safeToSpendMinor,
          overview.currency,
        );
        final AssistantInsightTone tone = switch (overview.health) {
          SafeToSpendHealth.healthy => AssistantInsightTone.positive,
          SafeToSpendHealth.caution => AssistantInsightTone.warning,
          SafeToSpendHealth.critical => AssistantInsightTone.critical,
          SafeToSpendHealth.unconfigured => AssistantInsightTone.info,
        };
        insights.add(
          AssistantDailyInsight(
            id: 'insight_safe_to_spend',
            title: 'Safe to Spend: $formattedSafe',
            detail:
                '${overview.health.label} • ${MoneyFormatter.formatMinorUnits(overview.unpaidObligationsMinor, overview.currency)} reserved for unpaid bills.',
            tone: tone,
            domain: AssistantSourceDomain.money,
            followUpPrompt: 'Magkano safe to spend ko?',
          ),
        );
      }
    }

    if (snapshot.bills.isReady && snapshot.dueSoonBills.isNotEmpty) {
      final int count = snapshot.dueSoonBills.length;
      final BillItem earliest = snapshot.dueSoonBills.first;
      final String earliestAmount = MoneyFormatter.formatMinorUnits(
        earliest.amountMinor,
        earliest.currency,
      );
      insights.add(
        AssistantDailyInsight(
          id: 'insight_bills_due_soon',
          title: count == 1 ? '1 bill due soon' : '$count bills due soon',
          detail:
              'Earliest: ${earliest.title} ($earliestAmount, ${earliest.dueStatusLabel(snapshot.referenceToday)}).',
          tone: snapshot.overdueBills.isNotEmpty
              ? AssistantInsightTone.critical
              : AssistantInsightTone.warning,
          domain: AssistantSourceDomain.bills,
          followUpPrompt: 'What bills are due soon?',
        ),
      );
    }

    if (snapshot.documents.isReady) {
      final int expiredCount = snapshot.expiredDocuments.length;
      final int expiringCount = snapshot.expiringSoonDocuments.length;
      if (expiredCount > 0 || expiringCount > 0) {
        insights.add(
          AssistantDailyInsight(
            id: 'insight_documents_attention',
            title: expiredCount > 0
                ? '$expiredCount expired document${expiredCount == 1 ? '' : 's'}'
                : '$expiringCount expiring soon',
            detail: expiredCount > 0
                ? 'Expired Life Vault records need renewal attention.'
                : 'Documents expiring within 30 days are ready for review.',
            tone: expiredCount > 0
                ? AssistantInsightTone.critical
                : AssistantInsightTone.warning,
            domain: AssistantSourceDomain.documents,
            followUpPrompt: 'Are my documents expiring?',
          ),
        );
      }
    }

    if (snapshot.routines.isReady &&
        snapshot.todayScheduledRoutines.isNotEmpty) {
      final KayaDateOnly today = snapshot.referenceToday;
      final int total = snapshot.todayScheduledRoutines.length;
      final int done = snapshot.todayScheduledRoutines
          .where((DailyRoutine r) => r.isCompletedOn(today))
          .length;
      insights.add(
        AssistantDailyInsight(
          id: 'insight_routines_today',
          title: 'Routines today: $done/$total done',
          detail: done == total
              ? 'All scheduled routines for today are complete.'
              : '${total - done} scheduled routine${total - done == 1 ? '' : 's'} remaining today.',
          tone: done == total
              ? AssistantInsightTone.positive
              : AssistantInsightTone.info,
          domain: AssistantSourceDomain.routines,
          followUpPrompt: 'Am I keeping up with my routines?',
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        const AssistantDailyInsight(
          id: 'insight_all_clear',
          title: 'All clear today',
          detail: 'No overdue tasks, urgent bills, or expiring documents on record.',
          tone: AssistantInsightTone.positive,
          domain: AssistantSourceDomain.system,
          followUpPrompt: 'Summarize my day.',
        ),
      );
    }

    return List<AssistantDailyInsight>.unmodifiable(insights.take(4));
  }
}
