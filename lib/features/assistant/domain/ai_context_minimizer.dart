import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_models.dart';
import 'package:kaya/features/assistant/domain/assistant_context_snapshot.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';

/// Builds a strictly minimized context payload for server-side AI requests.
///
/// Security & Privacy guarantees (Phase 9):
/// - Never includes user IDs, record IDs, raw notes, physical/storage locations,
///   counterparty names, or individual financial transactions.
/// - Excludes financial summary and document alerts unless the user explicitly
///   opted in via [AiConsentSettings].
abstract final class AiContextMinimizer {
  static const int maxTasksIncluded = 6;
  static const int maxDocsIncluded = 4;

  static AiMinimizedContextPayload buildMinimizedPayload({
    required AssistantContextSnapshot snapshot,
    required AiConsentSettings consent,
  }) {
    final KayaDateOnly today = snapshot.referenceToday;

    final List<TaskItem> priorityTasks = <TaskItem>[
      ...snapshot.overdueTasks,
      ...snapshot.todayTasks,
    ];

    final Map<String, Object?> taskSummary = snapshot.tasks.isReady
        ? <String, Object?>{
            'overdueCount': snapshot.overdueTasks.length,
            'todayCount': snapshot.todayTasks.length,
            'topItems': priorityTasks
                .take(maxTasksIncluded)
                .map(
                  (TaskItem t) => <String, String>{
                    'title': t.title,
                    'priority': t.priority.label,
                    'status': t.dueStatusLabel(today),
                  },
                )
                .toList(growable: false),
          }
        : <String, Object?>{'available': false};

    final int scheduledRoutines = snapshot.todayScheduledRoutines.length;
    final int doneRoutines = snapshot.todayScheduledRoutines
        .where((DailyRoutine r) => r.isCompletedOn(today))
        .length;
    final Map<String, Object?> routineSummary = snapshot.routines.isReady
        ? <String, Object?>{
            'scheduledToday': scheduledRoutines,
            'completedToday': doneRoutines,
          }
        : <String, Object?>{'available': false};

    Map<String, Object?>? financialSummary;
    if (consent.shareFinancialSummary &&
        snapshot.moneyOverview.isReady &&
        snapshot.bills.isReady) {
      final FinancialOverviewSummary? overview = snapshot.moneyOverview.data;
      if (overview != null && overview.hasAnyActivity) {
        financialSummary = <String, Object?>{
          'safeToSpend': MoneyFormatter.formatMinorUnits(
            overview.safeToSpendMinor,
            overview.currency,
          ),
          'health': overview.health.label,
          'dueSoonBillsCount': snapshot.dueSoonBills.length,
        };
      } else {
        financialSummary = <String, Object?>{'hasActivity': false};
      }
    }

    Map<String, Object?>? documentAlerts;
    if (consent.shareDocumentAlerts && snapshot.documents.isReady) {
      final List<VaultDocument> alerts = <VaultDocument>[
        ...snapshot.expiredDocuments,
        ...snapshot.expiringSoonDocuments,
      ];
      documentAlerts = <String, Object?>{
        'expiredCount': snapshot.expiredDocuments.length,
        'expiringSoonCount': snapshot.expiringSoonDocuments.length,
        'items': alerts
            .take(maxDocsIncluded)
            .map(
              (VaultDocument d) => <String, String>{
                'title': d.title,
                'status': d.expirationStatusLabel(today),
              },
            )
            .toList(growable: false),
      };
    }

    return AiMinimizedContextPayload(
      referenceDateIso: today.toIsoDateString(),
      taskSummary: taskSummary,
      routineSummary: routineSummary,
      financialSummary: financialSummary,
      documentAlerts: documentAlerts,
    );
  }
}
