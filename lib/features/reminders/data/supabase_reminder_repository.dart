import 'package:kaya/core/data/supabase_error_mapper.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/bill_reminder_validators.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/reminders/domain/reminder_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live Supabase implementation of [ReminderRepository] (Phase 5).
class SupabaseReminderRepository implements ReminderRepository {
  SupabaseReminderRepository({required this.client});

  final SupabaseClient client;

  ReminderItem _fromRow(Map<String, dynamic> row) {
    return ReminderItem(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      title: (row['title'] as String? ?? '').trim(),
      notes: (row['notes'] as String? ?? '').trim(),
      dueDate: SupabaseErrorMapper.parseDateOnly(row['due_date']),
      isCompleted: row['is_completed'] as bool? ?? false,
      completedAt: SupabaseErrorMapper.parseOptionalDateTimeUtc(
        row['completed_at'],
      ),
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  void _validate({
    required String title,
    required String notes,
    required KayaDateOnly dueDate,
  }) {
    final String? titleErr = BillReminderValidators.validateTitle(
      title,
      fieldName: 'Reminder title',
    );
    if (titleErr != null) {
      throw AuthFailure.validation(titleErr);
    }
    final String? notesErr = BillReminderValidators.validateNotes(notes);
    if (notesErr != null) {
      throw AuthFailure.validation(notesErr);
    }
    final String? dateErr = BillReminderValidators.validateDueDate(dueDate);
    if (dateErr != null) {
      throw AuthFailure.validation(dateErr);
    }
  }

  @override
  Future<List<ReminderItem>> fetchReminders({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
      requestedOwnerId: requestedOwnerId,
    );
    try {
      final List<dynamic> rows = await client
          .from('reminders')
          .select()
          .eq('user_id', uid)
          .order('due_date', ascending: true);
      return rows
          .map((dynamic row) => _fromRow(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Unable to load reminders.');
    }
  }

  @override
  Future<ReminderItem> createReminder({
    required String authenticatedUserId,
    required String title,
    String notes = '',
    required KayaDateOnly dueDate,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validate(title: title, notes: notes, dueDate: dueDate);
    try {
      final Map<String, dynamic> inserted = await client
          .from('reminders')
          .insert(<String, dynamic>{
            'user_id': uid,
            'title': title.trim(),
            'notes': notes.trim(),
            'due_date': dueDate.toIsoDateString(),
          })
          .select()
          .single();
      return _fromRow(inserted);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to create reminder.');
    }
  }

  @override
  Future<ReminderItem> updateReminder({
    required String authenticatedUserId,
    required String reminderId,
    required String title,
    required String notes,
    required KayaDateOnly dueDate,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validate(title: title, notes: notes, dueDate: dueDate);
    try {
      final Map<String, dynamic> updated = await client
          .from('reminders')
          .update(<String, dynamic>{
            'title': title.trim(),
            'notes': notes.trim(),
            'due_date': dueDate.toIsoDateString(),
          })
          .eq('id', reminderId)
          .eq('user_id', uid)
          .select()
          .single();
      return _fromRow(updated);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update reminder.');
    }
  }

  @override
  Future<ReminderItem> setReminderCompleted({
    required String authenticatedUserId,
    required String reminderId,
    required bool isCompleted,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      final Map<String, dynamic> updated = await client
          .from('reminders')
          .update(<String, dynamic>{
            'is_completed': isCompleted,
            'completed_at': isCompleted
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          })
          .eq('id', reminderId)
          .eq('user_id', uid)
          .select()
          .single();
      return _fromRow(updated);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update reminder.');
    }
  }

  @override
  Future<void> deleteReminder({
    required String authenticatedUserId,
    required String reminderId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('reminders')
          .delete()
          .eq('id', reminderId)
          .eq('user_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to delete reminder.');
    }
  }
}
