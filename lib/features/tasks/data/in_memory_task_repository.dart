import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/task_validators.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';
import 'package:kaya/features/tasks/domain/task_repository.dart';

/// Deterministic, RLS-enforcing implementation of [TaskRepository].
///
/// Mirrors the PostgreSQL constraints and Row Level Security policies in
/// `supabase/migrations/20261114000002_phase3_tasks.sql`.
class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, TaskItem> _tasksById = <String, TaskItem>{};
  int _nextTaskSequence = 1;

  /// Test hook to simulate network errors and verify error/retry states.
  bool simulateNetworkFailure = false;

  void _checkNetwork() {
    if (simulateNetworkFailure) {
      throw AuthFailure.network(
        'Unable to synchronize tasks. Please check your connection and try again.',
      );
    }
  }

  String _requireAuthenticatedUser(String authenticatedUserId) {
    final String trimmed = authenticatedUserId.trim();
    if (trimmed.isEmpty) {
      throw AuthFailure.unauthorizedAccess();
    }
    return trimmed;
  }

  TaskItem _requireOwnedTask({
    required String authenticatedUserId,
    required String taskId,
  }) {
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final TaskItem? existing = _tasksById[taskId.trim()];
    if (existing == null || existing.userId != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return existing;
  }

  void _validateTaskPayload({
    required String title,
    required String notes,
    required KayaDateOnly? dueDate,
  }) {
    final String? titleError = TaskValidators.validateTitle(title);
    if (titleError != null) {
      throw AuthFailure.validation(titleError);
    }
    final String? notesError = TaskValidators.validateNotes(notes);
    if (notesError != null) {
      throw AuthFailure.validation(notesError);
    }
    final String? dateError = TaskValidators.validateDueDate(dueDate);
    if (dateError != null) {
      throw AuthFailure.validation(dateError);
    }
  }

  @override
  Future<List<TaskItem>> fetchTasks({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }

    final List<TaskItem> owned = _tasksById.values
        .where((TaskItem t) => t.userId == uid)
        .toList();
    return owned;
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
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    _validateTaskPayload(title: title, notes: notes, dueDate: dueDate);

    final DateTime now = _clock().toUtc();
    final String taskId = 'tsk_${_nextTaskSequence++}';
    final TaskItem created = TaskItem(
      id: taskId,
      userId: uid,
      title: title.trim(),
      notes: notes.trim(),
      priority: priority,
      category: category,
      dueDate: dueDate,
      isCompleted: false,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
    );

    _tasksById[taskId] = created;
    return created;
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
    _checkNetwork();
    final TaskItem existing = _requireOwnedTask(
      authenticatedUserId: authenticatedUserId,
      taskId: taskId,
    );
    _validateTaskPayload(title: title, notes: notes, dueDate: dueDate);

    final TaskItem updated = existing.copyWith(
      title: title.trim(),
      notes: notes.trim(),
      priority: priority,
      category: category,
      dueDate: dueDate,
      clearDueDate: dueDate == null,
      updatedAt: _clock().toUtc(),
    );

    _tasksById[existing.id] = updated;
    return updated;
  }

  @override
  Future<TaskItem> setTaskCompleted({
    required String authenticatedUserId,
    required String taskId,
    required bool isCompleted,
  }) async {
    _checkNetwork();
    final TaskItem existing = _requireOwnedTask(
      authenticatedUserId: authenticatedUserId,
      taskId: taskId,
    );

    final DateTime now = _clock().toUtc();
    final TaskItem updated = existing.copyWith(
      isCompleted: isCompleted,
      completedAt: isCompleted ? now : null,
      clearCompletedAt: !isCompleted,
      updatedAt: now,
    );

    _tasksById[existing.id] = updated;
    return updated;
  }

  @override
  Future<void> deleteTask({
    required String authenticatedUserId,
    required String taskId,
  }) async {
    _checkNetwork();
    final TaskItem existing = _requireOwnedTask(
      authenticatedUserId: authenticatedUserId,
      taskId: taskId,
    );
    _tasksById.remove(existing.id);
  }
}
