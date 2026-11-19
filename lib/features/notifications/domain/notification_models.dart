/// OS notification permission state for Android/local notifications (Phase 10).
enum NotificationPermissionStatus {
  notDetermined(label: 'Not Enabled'),
  granted(label: 'Allowed'),
  denied(label: 'Denied');

  const NotificationPermissionStatus({required this.label});

  final String label;
}

/// Android local notification channels grouped by KAYA domain.
enum KayaNotificationChannel {
  tasks(channelId: 'kaya_tasks', label: 'Task Reminders'),
  bills(channelId: 'kaya_bills', label: 'Bill Reminders'),
  documents(channelId: 'kaya_documents', label: 'Document Alerts'),
  routines(channelId: 'kaya_routines', label: 'Routine Reminders');

  const KayaNotificationChannel({required this.channelId, required this.label});

  final String channelId;
  final String label;
}

/// Quiet hours window supporting both overnight (e.g., 22:00–07:00) and
/// same-day (e.g., 13:00–15:00) silent windows.
class QuietHoursWindow {
  const QuietHoursWindow({
    this.enabled = true,
    this.startHour = 22,
    this.startMinute = 0,
    this.endHour = 7,
    this.endMinute = 0,
  });

  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  int get _startTotalMinutes => (startHour * 60) + startMinute;
  int get _endTotalMinutes => (endHour * 60) + endMinute;

  String get formattedRange =>
      '${_pad(startHour)}:${_pad(startMinute)} – ${_pad(endHour)}:${_pad(endMinute)}';

  static String _pad(int v) => v.toString().padLeft(2, '0');

  bool isWithinQuietHours(DateTime dateTime) {
    if (!enabled || _startTotalMinutes == _endTotalMinutes) {
      return false;
    }
    final int currentMinutes = (dateTime.hour * 60) + dateTime.minute;
    if (_startTotalMinutes < _endTotalMinutes) {
      // Same-day quiet hours (e.g., 13:00 to 15:00).
      return currentMinutes >= _startTotalMinutes &&
          currentMinutes < _endTotalMinutes;
    }
    // Overnight quiet hours (e.g., 22:00 to 07:00).
    return currentMinutes >= _startTotalMinutes ||
        currentMinutes < _endTotalMinutes;
  }

  /// Shifts [scheduledAt] forward to the end of quiet hours if it falls inside
  /// the active quiet window; otherwise returns [scheduledAt] unchanged.
  DateTime adjustForQuietHours(DateTime scheduledAt) {
    if (!isWithinQuietHours(scheduledAt)) {
      return scheduledAt;
    }
    final int currentMinutes = (scheduledAt.hour * 60) + scheduledAt.minute;
    if (_startTotalMinutes < _endTotalMinutes) {
      return DateTime(
        scheduledAt.year,
        scheduledAt.month,
        scheduledAt.day,
        endHour,
        endMinute,
      );
    }
    // Overnight window: if after start (e.g. 23:00), push to next morning;
    // if before end (e.g. 05:00), push to end today.
    if (currentMinutes >= _startTotalMinutes) {
      final DateTime nextDay = DateTime(
        scheduledAt.year,
        scheduledAt.month,
        scheduledAt.day,
      ).add(const Duration(days: 1));
      return DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        endHour,
        endMinute,
      );
    }
    return DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
      endHour,
      endMinute,
    );
  }

  QuietHoursWindow copyWith({
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return QuietHoursWindow(
      enabled: enabled ?? this.enabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is QuietHoursWindow &&
        other.enabled == enabled &&
        other.startHour == startHour &&
        other.startMinute == startMinute &&
        other.endHour == endHour &&
        other.endMinute == endMinute;
  }

  @override
  int get hashCode =>
      Object.hash(enabled, startHour, startMinute, endHour, endMinute);
}

/// Per-user notification toggles, reminder times, lead days, and quiet hours.
class NotificationPreferences {
  const NotificationPreferences({
    this.notificationsEnabled = true,
    this.taskRemindersEnabled = true,
    this.billRemindersEnabled = true,
    this.documentAlertsEnabled = true,
    this.routineRemindersEnabled = true,
    this.dailyReminderHour = 9,
    this.dailyReminderMinute = 0,
    this.routineReminderHour = 8,
    this.routineReminderMinute = 0,
    this.billLeadDays = 3,
    this.documentLeadDays = 14,
    this.quietHours = const QuietHoursWindow(),
  });

  final bool notificationsEnabled;
  final bool taskRemindersEnabled;
  final bool billRemindersEnabled;
  final bool documentAlertsEnabled;
  final bool routineRemindersEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final int routineReminderHour;
  final int routineReminderMinute;
  final int billLeadDays;
  final int documentLeadDays;
  final QuietHoursWindow quietHours;

  NotificationPreferences copyWith({
    bool? notificationsEnabled,
    bool? taskRemindersEnabled,
    bool? billRemindersEnabled,
    bool? documentAlertsEnabled,
    bool? routineRemindersEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    int? routineReminderHour,
    int? routineReminderMinute,
    int? billLeadDays,
    int? documentLeadDays,
    QuietHoursWindow? quietHours,
  }) {
    return NotificationPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
      billRemindersEnabled: billRemindersEnabled ?? this.billRemindersEnabled,
      documentAlertsEnabled:
          documentAlertsEnabled ?? this.documentAlertsEnabled,
      routineRemindersEnabled:
          routineRemindersEnabled ?? this.routineRemindersEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      routineReminderHour: routineReminderHour ?? this.routineReminderHour,
      routineReminderMinute:
          routineReminderMinute ?? this.routineReminderMinute,
      billLeadDays: billLeadDays ?? this.billLeadDays,
      documentLeadDays: documentLeadDays ?? this.documentLeadDays,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is NotificationPreferences &&
        other.notificationsEnabled == notificationsEnabled &&
        other.taskRemindersEnabled == taskRemindersEnabled &&
        other.billRemindersEnabled == billRemindersEnabled &&
        other.documentAlertsEnabled == documentAlertsEnabled &&
        other.routineRemindersEnabled == routineRemindersEnabled &&
        other.dailyReminderHour == dailyReminderHour &&
        other.dailyReminderMinute == dailyReminderMinute &&
        other.routineReminderHour == routineReminderHour &&
        other.routineReminderMinute == routineReminderMinute &&
        other.billLeadDays == billLeadDays &&
        other.documentLeadDays == documentLeadDays &&
        other.quietHours == quietHours;
  }

  @override
  int get hashCode => Object.hash(
    notificationsEnabled,
    taskRemindersEnabled,
    billRemindersEnabled,
    documentAlertsEnabled,
    routineRemindersEnabled,
    dailyReminderHour,
    dailyReminderMinute,
    routineReminderHour,
    routineReminderMinute,
    billLeadDays,
    documentLeadDays,
    quietHours,
  );
}

/// Deduplicated local notification payload scheduled for the authenticated user.
///
/// Privacy rule (Section 7): [toString] redacts private title/body text.
class ScheduledKayaNotification {
  const ScheduledKayaNotification({
    required this.id,
    required this.dedupeKey,
    required this.userId,
    required this.channel,
    required this.title,
    required this.body,
    required this.scheduledAt,
    this.isRecurringWeekly = false,
    this.recurringIsoWeekday,
  });

  final int id;
  final String dedupeKey;
  final String userId;
  final KayaNotificationChannel channel;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final bool isRecurringWeekly;
  final int? recurringIsoWeekday;

  @override
  String toString() =>
      'ScheduledKayaNotification(id: $id, channel: ${channel.channelId}, scheduledAt: ${scheduledAt.toIso8601String()}, recurring: $isRecurringWeekly, body: [REDACTED])';
}
