import 'package:kaya/core/utils/kaya_date_only.dart';

/// ISO-8601 weekday descriptors (`1 = Monday .. 7 = Sunday`) for routine
/// scheduling.
enum RoutineWeekday {
  monday(isoWeekday: 1, shortLabel: 'Mon', fullLabel: 'Monday'),
  tuesday(isoWeekday: 2, shortLabel: 'Tue', fullLabel: 'Tuesday'),
  wednesday(isoWeekday: 3, shortLabel: 'Wed', fullLabel: 'Wednesday'),
  thursday(isoWeekday: 4, shortLabel: 'Thu', fullLabel: 'Thursday'),
  friday(isoWeekday: 5, shortLabel: 'Fri', fullLabel: 'Friday'),
  saturday(isoWeekday: 6, shortLabel: 'Sat', fullLabel: 'Saturday'),
  sunday(isoWeekday: 7, shortLabel: 'Sun', fullLabel: 'Sunday');

  const RoutineWeekday({
    required this.isoWeekday,
    required this.shortLabel,
    required this.fullLabel,
  });

  final int isoWeekday;
  final String shortLabel;
  final String fullLabel;

  static Set<int> get allWeekdays => const <int>{1, 2, 3, 4, 5, 6, 7};

  static String formatScheduleSummary(Set<int> isoWeekdays) {
    if (isoWeekdays.length == 7) {
      return 'Every day';
    }
    if (isoWeekdays.length == 5 &&
        isoWeekdays.containsAll(const <int>[1, 2, 3, 4, 5])) {
      return 'Weekdays';
    }
    if (isoWeekdays.length == 2 && isoWeekdays.containsAll(const <int>[6, 7])) {
      return 'Weekends';
    }
    final List<String> labels = <String>[
      for (final RoutineWeekday day in RoutineWeekday.values)
        if (isoWeekdays.contains(day.isoWeekday)) day.shortLabel,
    ];
    return labels.join(', ');
  }
}

/// Ordered step inside a [DailyRoutine].
class RoutineStep {
  const RoutineStep({required this.id, required this.title});

  final String id;
  final String title;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RoutineStep && other.id == id && other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, title);
}

/// Daily or recurring-weekday routine with step-by-step completion and
/// calendar-accurate streak tracking (Phase 7).
class DailyRoutine {
  const DailyRoutine({
    required this.id,
    required this.userId,
    required this.title,
    required this.scheduledWeekdays,
    required this.steps,
    required this.completedStepIdsByDateKey,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final Set<int> scheduledWeekdays;
  final List<RoutineStep> steps;
  final Map<String, Set<String>> completedStepIdsByDateKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isScheduledOn(KayaDateOnly date) =>
      scheduledWeekdays.contains(date.weekday);

  Set<String> completedStepIdsFor(KayaDateOnly date) {
    return completedStepIdsByDateKey[date.toIsoDateString()] ??
        const <String>{};
  }

  bool isStepCompletedOn(String stepId, KayaDateOnly date) =>
      completedStepIdsFor(date).contains(stepId);

  int completedStepsCountOn(KayaDateOnly date) {
    final Set<String> done = completedStepIdsFor(date);
    return steps.where((RoutineStep s) => done.contains(s.id)).length;
  }

  bool isCompletedOn(KayaDateOnly date) =>
      steps.isNotEmpty && completedStepsCountOn(date) == steps.length;

  double progressRatioOn(KayaDateOnly date) =>
      steps.isEmpty ? 0.0 : completedStepsCountOn(date) / steps.length;

  /// Calculates consecutive completed scheduled days ending at or before
  /// [referenceToday].
  ///
  /// Unscheduled rest days are skipped without breaking the streak, and if
  /// [referenceToday] is scheduled but still in progress, earlier consecutive
  /// scheduled days are preserved until missed.
  int currentStreak(KayaDateOnly referenceToday) {
    if (steps.isEmpty || scheduledWeekdays.isEmpty) {
      return 0;
    }
    int streak = 0;
    for (int offset = 0; offset < 365; offset++) {
      final KayaDateOnly date = referenceToday.addDays(-offset);
      if (!isScheduledOn(date)) {
        continue;
      }
      if (isCompletedOn(date)) {
        streak++;
      } else if (offset == 0) {
        // Today's scheduled routine is still open; check prior scheduled days.
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  DailyRoutine copyWith({
    String? id,
    String? userId,
    String? title,
    Set<int>? scheduledWeekdays,
    List<RoutineStep>? steps,
    Map<String, Set<String>>? completedStepIdsByDateKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyRoutine(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      scheduledWeekdays: scheduledWeekdays ?? this.scheduledWeekdays,
      steps: steps ?? this.steps,
      completedStepIdsByDateKey:
          completedStepIdsByDateKey ?? this.completedStepIdsByDateKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
