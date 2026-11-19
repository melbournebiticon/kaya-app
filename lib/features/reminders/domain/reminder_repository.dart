import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';

/// Repository contract for Phase 5 Reminders Management.
///
/// Mirrors PostgreSQL constraints and RLS policies in
/// `supabase/migrations/20261114000004_phase5_bills_and_reminders.sql`.
abstract class ReminderRepository {
  Future<List<ReminderItem>> fetchReminders({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  Future<ReminderItem> createReminder({
    required String authenticatedUserId,
    required String title,
    String notes = '',
    required KayaDateOnly dueDate,
  });

  Future<ReminderItem> updateReminder({
    required String authenticatedUserId,
    required String reminderId,
    required String title,
    required String notes,
    required KayaDateOnly dueDate,
  });

  Future<ReminderItem> setReminderCompleted({
    required String authenticatedUserId,
    required String reminderId,
    required bool isCompleted,
  });

  Future<void> deleteReminder({
    required String authenticatedUserId,
    required String reminderId,
  });
}
