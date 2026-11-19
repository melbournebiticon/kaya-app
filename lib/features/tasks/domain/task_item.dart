import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';

/// Immutable user-owned task entity for KAYA Phase 3.
///
/// Enforces Section 5 Functional Rules:
/// - `dueDate` is a [KayaDateOnly] value object (separated from `DateTime` timestamps).
/// - Uses stable `id` and `userId` ownership binding.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.userId,
    required this.title,
    this.notes = '',
    this.priority = TaskPriority.medium,
    this.category = TaskCategory.personal,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String notes;
  final TaskPriority priority;
  final TaskCategory category;
  final KayaDateOnly? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Evaluates the task's due bucket relative to [referenceToday].
  TaskDueBucket dueBucket(KayaDateOnly referenceToday) {
    final KayaDateOnly? due = dueDate;
    if (due == null) {
      return TaskDueBucket.noDueDate;
    }
    if (due.isBefore(referenceToday)) {
      return TaskDueBucket.overdue;
    }
    if (due.isSameDay(referenceToday)) {
      return TaskDueBucket.today;
    }
    return TaskDueBucket.upcoming;
  }

  /// True if the task is incomplete and its due date is strictly before [referenceToday].
  bool isOverdue(KayaDateOnly referenceToday) =>
      !isCompleted && dueBucket(referenceToday) == TaskDueBucket.overdue;

  /// True if the task is incomplete and due on [referenceToday].
  bool isDueToday(KayaDateOnly referenceToday) =>
      !isCompleted && dueBucket(referenceToday) == TaskDueBucket.today;

  /// True if the task is incomplete and due strictly after [referenceToday].
  bool isUpcoming(KayaDateOnly referenceToday) =>
      !isCompleted && dueBucket(referenceToday) == TaskDueBucket.upcoming;

  /// Human-readable due status label relative to [referenceToday].
  String dueStatusLabel(KayaDateOnly referenceToday) {
    final KayaDateOnly? due = dueDate;
    if (due == null) {
      return 'No due date';
    }
    final int diffDays = due.daysDifferenceFrom(referenceToday);
    if (diffDays == 0) {
      return 'Due Today';
    }
    if (diffDays == 1) {
      return 'Due Tomorrow';
    }
    if (diffDays == -1) {
      return 'Overdue by 1 day';
    }
    if (diffDays < -1) {
      return 'Overdue by ${diffDays.abs()} days';
    }
    if (diffDays <= 7) {
      return 'Due in $diffDays days';
    }
    return 'Due ${due.formatReadable()}';
  }

  TaskItem copyWith({
    String? title,
    String? notes,
    TaskPriority? priority,
    TaskCategory? category,
    KayaDateOnly? dueDate,
    bool clearDueDate = false,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) {
    return TaskItem(
      id: id,
      userId: userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Deterministic urgency comparator used for Today's Priority Queue and
  /// identifying "What is my most important task?".
  ///
  /// Ordering:
  /// 1. Incomplete tasks before completed tasks.
  /// 2. Overdue tasks -> Due Today -> Upcoming -> No due date.
  /// 3. Higher priority (`urgent` > `high` > `medium` > `low`).
  /// 4. Earlier due date.
  /// 5. Earlier creation timestamp.
  static int compareByUrgency(
    TaskItem a,
    TaskItem b,
    KayaDateOnly referenceToday,
  ) {
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }

    int bucketRank(TaskDueBucket bucket) {
      return switch (bucket) {
        TaskDueBucket.overdue => 0,
        TaskDueBucket.today => 1,
        TaskDueBucket.upcoming => 2,
        TaskDueBucket.noDueDate => 3,
      };
    }

    final int rankA = bucketRank(a.dueBucket(referenceToday));
    final int rankB = bucketRank(b.dueBucket(referenceToday));
    if (rankA != rankB) {
      return rankA.compareTo(rankB);
    }

    if (a.priority.weight != b.priority.weight) {
      return b.priority.weight.compareTo(a.priority.weight);
    }

    if (a.dueDate != null && b.dueDate != null) {
      final int dueCompare = a.dueDate!.compareTo(b.dueDate!);
      if (dueCompare != 0) {
        return dueCompare;
      }
    }

    return a.createdAt.compareTo(b.createdAt);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TaskItem &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.notes == notes &&
        other.priority == priority &&
        other.category == category &&
        other.dueDate == dueDate &&
        other.isCompleted == isCompleted &&
        other.completedAt == completedAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    notes,
    priority,
    category,
    dueDate,
    isCompleted,
    completedAt,
    createdAt,
    updatedAt,
  );
}
