import 'package:kaya/core/utils/kaya_date_only.dart';

/// Relative calendar due-date classification for active reminders.
enum ReminderDueBucket { overdue, today, upcoming }

/// Filter views supported in the Reminders workspace.
enum ReminderFilterView {
  active(label: 'Active'),
  overdue(label: 'Overdue'),
  today(label: 'Today'),
  upcoming(label: 'Upcoming'),
  completed(label: 'Completed');

  const ReminderFilterView({required this.label});

  final String label;
}

/// Immutable domain entity representing a user-owned date reminder in Phase 5.
class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.notes,
    required this.dueDate,
    required this.isCompleted,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String notes;
  final KayaDateOnly dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReminderDueBucket dueBucket(KayaDateOnly referenceToday) {
    final int cmp = dueDate.compareTo(referenceToday);
    if (cmp < 0) {
      return ReminderDueBucket.overdue;
    }
    if (cmp == 0) {
      return ReminderDueBucket.today;
    }
    return ReminderDueBucket.upcoming;
  }

  bool isOverdue(KayaDateOnly referenceToday) =>
      !isCompleted && dueBucket(referenceToday) == ReminderDueBucket.overdue;

  bool isDueToday(KayaDateOnly referenceToday) =>
      !isCompleted && dueBucket(referenceToday) == ReminderDueBucket.today;

  bool isUpcoming(KayaDateOnly referenceToday) =>
      !isCompleted && dueBucket(referenceToday) == ReminderDueBucket.upcoming;

  String dueStatusLabel(KayaDateOnly referenceToday) {
    if (isCompleted) {
      return 'Completed';
    }
    final int deltaDays = dueDate.daysDifferenceFrom(referenceToday);
    if (deltaDays < 0) {
      final int overdueDays = -deltaDays;
      return overdueDays == 1
          ? 'Overdue by 1 day'
          : 'Overdue by $overdueDays days';
    }
    if (deltaDays == 0) {
      return 'Today';
    }
    if (deltaDays == 1) {
      return 'Tomorrow';
    }
    return 'In $deltaDays days';
  }

  ReminderItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? notes,
    KayaDateOnly? dueDate,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int compareByUrgency(
    ReminderItem a,
    ReminderItem b,
    KayaDateOnly referenceToday,
  ) {
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }
    final int dateCmp = a.dueDate.compareTo(b.dueDate);
    if (dateCmp != 0) {
      return dateCmp;
    }
    final int titleCmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (titleCmp != 0) {
      return titleCmp;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ReminderItem &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.notes == notes &&
        other.dueDate == dueDate &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, title, notes, dueDate, isCompleted);
}
