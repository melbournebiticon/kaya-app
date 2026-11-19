import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/notifications/domain/notification_models.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';

/// Deterministic local notification scheduler for Phase 10.
///
/// Guarantees:
/// - Zero duplicate notifications via stable FNV-1a IDs and deduplication map.
/// - Excludes completed tasks, completed reminders, and paid bills.
/// - Respects [QuietHoursWindow] by shifting silent-hour triggers forward.
/// - Never includes private Life Vault notes or physical locations in alert text.
abstract final class NotificationScheduleEngine {
  /// Stable positive 31-bit Android-safe notification ID derived from [dedupeKey].
  static int stableNotificationId(String dedupeKey) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < dedupeKey.length; i++) {
      hash ^= dedupeKey.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static List<ScheduledKayaNotification> buildSchedule({
    required String userId,
    required NotificationPreferences preferences,
    required DateTime now,
    required List<TaskItem> tasks,
    required List<BillItem> bills,
    required List<ReminderItem> reminders,
    required List<VaultDocument> documents,
    required List<DailyRoutine> routines,
  }) {
    if (!preferences.notificationsEnabled || userId.trim().isEmpty) {
      return const <ScheduledKayaNotification>[];
    }

    final Map<String, ScheduledKayaNotification> byKey =
        <String, ScheduledKayaNotification>{};

    void addIfFuture({
      required String dedupeKey,
      required KayaNotificationChannel channel,
      required String title,
      required String body,
      required DateTime rawTriggerAt,
      bool isRecurringWeekly = false,
      int? recurringIsoWeekday,
    }) {
      final DateTime adjusted = preferences.quietHours.adjustForQuietHours(
        rawTriggerAt,
      );
      if (!adjusted.isAfter(now)) {
        return;
      }
      byKey[dedupeKey] = ScheduledKayaNotification(
        id: stableNotificationId(dedupeKey),
        dedupeKey: dedupeKey,
        userId: userId,
        channel: channel,
        title: title,
        body: body,
        scheduledAt: adjusted,
        isRecurringWeekly: isRecurringWeekly,
        recurringIsoWeekday: recurringIsoWeekday,
      );
    }

    // 1. Task & general reminder alerts.
    if (preferences.taskRemindersEnabled) {
      for (final TaskItem task in tasks) {
        if (task.isCompleted || task.dueDate == null) {
          continue;
        }
        final KayaDateOnly due = task.dueDate!;
        addIfFuture(
          dedupeKey: '$userId|task|${task.id}|${due.toIsoDateString()}',
          channel: KayaNotificationChannel.tasks,
          title: 'Task due today',
          body: '${task.title} (${task.priority.label} priority)',
          rawTriggerAt: DateTime(
            due.year,
            due.month,
            due.day,
            preferences.dailyReminderHour,
            preferences.dailyReminderMinute,
          ),
        );
      }

      for (final ReminderItem rem in reminders) {
        if (rem.isCompleted) {
          continue;
        }
        final KayaDateOnly due = rem.dueDate;
        addIfFuture(
          dedupeKey: '$userId|reminder|${rem.id}|${due.toIsoDateString()}',
          channel: KayaNotificationChannel.tasks,
          title: 'KAYA Reminder',
          body: rem.title,
          rawTriggerAt: DateTime(
            due.year,
            due.month,
            due.day,
            preferences.dailyReminderHour,
            preferences.dailyReminderMinute,
          ),
        );
      }
    }

    // 2. Unpaid bill reminders (advance warning + due date morning).
    if (preferences.billRemindersEnabled) {
      for (final BillItem bill in bills) {
        if (bill.isPaid) {
          continue;
        }
        final String amountText = MoneyFormatter.formatMinorUnits(
          bill.amountMinor,
          bill.currency,
        );
        if (preferences.billLeadDays > 0) {
          final KayaDateOnly advanceDate = bill.dueDate.addDays(
            -preferences.billLeadDays,
          );
          addIfFuture(
            dedupeKey:
                '$userId|bill_advance|${bill.id}|${advanceDate.toIsoDateString()}',
            channel: KayaNotificationChannel.bills,
            title: 'Upcoming bill in ${preferences.billLeadDays}d',
            body:
                '${bill.title} ($amountText) due ${bill.dueDate.formatReadable()}',
            rawTriggerAt: DateTime(
              advanceDate.year,
              advanceDate.month,
              advanceDate.day,
              preferences.dailyReminderHour,
              preferences.dailyReminderMinute,
            ),
          );
        }
        addIfFuture(
          dedupeKey:
              '$userId|bill_due|${bill.id}|${bill.dueDate.toIsoDateString()}',
          channel: KayaNotificationChannel.bills,
          title: 'Bill due today',
          body: '${bill.title} ($amountText) is due today.',
          rawTriggerAt: DateTime(
            bill.dueDate.year,
            bill.dueDate.month,
            bill.dueDate.day,
            preferences.dailyReminderHour,
            preferences.dailyReminderMinute,
          ),
        );
      }
    }

    // 3. Document expiration alerts (privacy-safe: omits notes & physical location).
    if (preferences.documentAlertsEnabled) {
      for (final VaultDocument doc in documents) {
        final KayaDateOnly? exp = doc.expirationDate;
        if (exp == null) {
          continue;
        }
        final KayaDateOnly advanceDate = exp.addDays(
          -preferences.documentLeadDays,
        );
        addIfFuture(
          dedupeKey:
              '$userId|doc_advance|${doc.id}|${advanceDate.toIsoDateString()}',
          channel: KayaNotificationChannel.documents,
          title: 'Document expiring soon',
          body: '${doc.title} expires on ${exp.formatReadable()}.',
          rawTriggerAt: DateTime(
            advanceDate.year,
            advanceDate.month,
            advanceDate.day,
            preferences.dailyReminderHour,
            preferences.dailyReminderMinute,
          ),
        );
        final KayaDateOnly eveDate = exp.addDays(-1);
        addIfFuture(
          dedupeKey: '$userId|doc_eve|${doc.id}|${eveDate.toIsoDateString()}',
          channel: KayaNotificationChannel.documents,
          title: 'Document expires tomorrow',
          body: '${doc.title} expires on ${exp.formatReadable()}.',
          rawTriggerAt: DateTime(
            eveDate.year,
            eveDate.month,
            eveDate.day,
            preferences.dailyReminderHour,
            preferences.dailyReminderMinute,
          ),
        );
      }
    }

    // 4. Recurring weekly routine reminders.
    if (preferences.routineRemindersEnabled) {
      final KayaDateOnly today = KayaDateOnly.fromDateTime(now);
      for (final DailyRoutine routine in routines) {
        final List<int> sortedDays = routine.scheduledWeekdays.toList()..sort();
        for (final int weekday in sortedDays) {
          final DateTime nextOccurrence = _nextWeeklyOccurrence(
            today: today,
            now: now,
            targetIsoWeekday: weekday,
            hour: preferences.routineReminderHour,
            minute: preferences.routineReminderMinute,
          );
          addIfFuture(
            dedupeKey: '$userId|routine|${routine.id}|wd_$weekday',
            channel: KayaNotificationChannel.routines,
            title: 'Routine reminder',
            body: 'Time for "${routine.title}".',
            rawTriggerAt: nextOccurrence,
            isRecurringWeekly: true,
            recurringIsoWeekday: weekday,
          );
        }
      }
    }

    final List<ScheduledKayaNotification> result = byKey.values.toList()
      ..sort((ScheduledKayaNotification a, ScheduledKayaNotification b) {
        final int timeCmp = a.scheduledAt.compareTo(b.scheduledAt);
        if (timeCmp != 0) {
          return timeCmp;
        }
        return a.dedupeKey.compareTo(b.dedupeKey);
      });
    return List<ScheduledKayaNotification>.unmodifiable(result);
  }

  static DateTime _nextWeeklyOccurrence({
    required KayaDateOnly today,
    required DateTime now,
    required int targetIsoWeekday,
    required int hour,
    required int minute,
  }) {
    int deltaDays = (targetIsoWeekday - today.weekday) % 7;
    if (deltaDays < 0) {
      deltaDays += 7;
    }
    KayaDateOnly candidateDate = today.addDays(deltaDays);
    DateTime candidate = DateTime(
      candidateDate.year,
      candidateDate.month,
      candidateDate.day,
      hour,
      minute,
    );
    if (!candidate.isAfter(now)) {
      candidateDate = candidateDate.addDays(7);
      candidate = DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
        hour,
        minute,
      );
    }
    return candidate;
  }
}
