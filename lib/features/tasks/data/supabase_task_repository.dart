import 'package:kaya/core/data/supabase_error_mapper.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/task_validators.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';
import 'package:kaya/features/tasks/domain/task_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live Supabase implementation of [TaskRepository] (Phase 3).
class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository({required this.client});

  final SupabaseClient client;

  TaskItem _fromRow(Map<String, dynamic> row) {
    return TaskItem(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      title: (row['title'] as String? ?? '').trim(),
      notes: (row['notes'] as String? ?? '').trim(),
      priority:
          TaskPriority.tryFromId(row['priority'] as String?) ??
          TaskPriority.medium,
      category:
          TaskCategory.tryFromId(row['category'] as String?) ??
          TaskCategory.personal,
      dueDate: SupabaseErrorMapper.parseOptionalDateOnly(row['due_date']),
      isCompleted: row['is_completed'] as bool? ?? false,
      completedAt: SupabaseErrorMapper.parseOptionalDateTimeUtc(
        row['completed_at'],
      ),
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  void _validateFields({
    required String title,
    required String notes,
    required KayaDateOnly? dueDate,
  }) {
    final String? titleErr = TaskValidators.validateTitle(title);
    if (titleErr != null) {
      throw AuthFailure.validation(titleErr);
    }
    final String? notesErr = TaskValidators.validateNotes(notes);
    if (notesErr != null) {
      throw AuthFailure.validation(notesErr);
    }
    final String? dateErr = TaskValidators.validateDueDate(dueDate);
    if (dateErr != null) {
      throw AuthFailure.validation(dateErr);
    }
  }

  @override
  Future<List<TaskItem>> fetchTasks({
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
          .from('tasks')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: true);
      return rows
          .map((dynamic row) => _fromRow(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(
        e,
        fallbackMessage: 'Unable to load tasks. Please try again.',
      );
    } catch (_) {
      throw AuthFailure.network('Unable to load tasks. Please try again.');
    }
  }

  @override
  Future<TaskItem> createTask({
    required String authenticatedUserId,
    required String title,
    String notes = '',
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.personal,
    KayaDateOnly? dueDate,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateFields(title: title, notes: notes, dueDate: dueDate);

    try {
      final Map<String, dynamic> inserted = await client
          .from('tasks')
          .insert(<String, dynamic>{
            'user_id': uid,
            'title': title.trim(),
            'notes': notes.trim(),
            'priority': priority.id,
            'category': category.id,
            'due_date': dueDate?.toIsoDateString(),
          })
          .select()
          .single();
      return _fromRow(inserted);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(
        e,
        fallbackMessage: 'Failed to create task. Please try again.',
      );
    } catch (_) {
      throw AuthFailure.network('Failed to create task. Please try again.');
    }
  }

  @override
  Future<TaskItem> updateTask({
    required String authenticatedUserId,
    required String taskId,
    required String title,
    required String notes,
    required TaskPriority priority,
    required TaskCategory category,
    required KayaDateOnly? dueDate,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateFields(title: title, notes: notes, dueDate: dueDate);

    try {
      final Map<String, dynamic> updated = await client
          .from('tasks')
          .update(<String, dynamic>{
            'title': title.trim(),
            'notes': notes.trim(),
            'priority': priority.id,
            'category': category.id,
            'due_date': dueDate?.toIsoDateString(),
          })
          .eq('id', taskId)
          .eq('user_id', uid)
          .select()
          .single();
      return _fromRow(updated);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(
        e,
        fallbackMessage: 'Failed to update task. Please try again.',
      );
    } catch (_) {
      throw AuthFailure.network('Failed to update task. Please try again.');
    }
  }

  @override
  Future<TaskItem> setTaskCompleted({
    required String authenticatedUserId,
    required String taskId,
    required bool isCompleted,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      final Map<String, dynamic> updated = await client
          .from('tasks')
          .update(<String, dynamic>{
            'is_completed': isCompleted,
            'completed_at': isCompleted
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          })
          .eq('id', taskId)
          .eq('user_id', uid)
          .select()
          .single();
      return _fromRow(updated);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(
        e,
        fallbackMessage: 'Failed to update task status. Please try again.',
      );
    } catch (_) {
      throw AuthFailure.network(
        'Failed to update task status. Please try again.',
      );
    }
  }

  @override
  Future<void> deleteTask({
    required String authenticatedUserId,
    required String taskId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client.from('tasks').delete().eq('id', taskId).eq('user_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(
        e,
        fallbackMessage: 'Failed to delete task. Please try again.',
      );
    } catch (_) {
      throw AuthFailure.network('Failed to delete task. Please try again.');
    }
  }
}
