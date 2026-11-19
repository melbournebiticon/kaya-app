import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';

/// Repository contract for Phase 3 Task Management.
///
/// Enforces server-side input validation and Row Level Security (`user_id == auth.uid()`).
abstract class TaskRepository {
  /// Fetches all tasks owned by [authenticatedUserId].
  ///
  /// If [requestedOwnerId] is provided and does not match [authenticatedUserId],
  /// throws an unauthorized access failure (RLS enforcement).
  Future<List<TaskItem>> fetchTasks({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  /// Creates a new task owned strictly by [authenticatedUserId].
  Future<TaskItem> createTask({
    required String authenticatedUserId,
    required String title,
    String notes = '',
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.personal,
    KayaDateOnly? dueDate,
  });

  /// Updates an existing task after verifying ownership (`task.userId == authenticatedUserId`).
  Future<TaskItem> updateTask({
    required String authenticatedUserId,
    required String taskId,
    required String title,
    required String notes,
    required TaskPriority priority,
    required TaskCategory category,
    required KayaDateOnly? dueDate,
  });

  /// Completes or reopens an existing task after verifying ownership.
  Future<TaskItem> setTaskCompleted({
    required String authenticatedUserId,
    required String taskId,
    required bool isCompleted,
  });

  /// Deletes an existing task after verifying ownership.
  Future<void> deleteTask({
    required String authenticatedUserId,
    required String taskId,
  });
}
