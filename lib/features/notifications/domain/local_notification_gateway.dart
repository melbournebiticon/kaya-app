import 'package:kaya/features/notifications/domain/notification_models.dart';

/// Platform abstraction for scheduling, reconciling, and cancelling local
/// notifications (Android `POST_NOTIFICATIONS` / local scheduler).
abstract class LocalNotificationGateway {
  Future<NotificationPermissionStatus> checkPermission();
  Future<NotificationPermissionStatus> requestPermission();
  Future<void> syncScheduledNotifications({
    required List<ScheduledKayaNotification> desired,
  });
  Future<void> cancelAll();
  List<ScheduledKayaNotification> get activeScheduledSnapshot;
}

/// Deterministic in-memory local notification gateway enforcing deduplication
/// by [ScheduledKayaNotification.id] and clean cancellation on disable/logout.
class InMemoryLocalNotificationGateway implements LocalNotificationGateway {
  InMemoryLocalNotificationGateway({
    NotificationPermissionStatus initialPermission =
        NotificationPermissionStatus.notDetermined,
    this.grantOnRequest = true,
  }) : _permission = initialPermission;

  NotificationPermissionStatus _permission;
  bool grantOnRequest;
  final Map<int, ScheduledKayaNotification> _scheduledById =
      <int, ScheduledKayaNotification>{};

  @override
  Future<NotificationPermissionStatus> checkPermission() async => _permission;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    _permission = grantOnRequest
        ? NotificationPermissionStatus.granted
        : NotificationPermissionStatus.denied;
    return _permission;
  }

  @override
  Future<void> syncScheduledNotifications({
    required List<ScheduledKayaNotification> desired,
  }) async {
    if (_permission != NotificationPermissionStatus.granted) {
      _scheduledById.clear();
      return;
    }
    _scheduledById
      ..clear()
      ..addEntries(
        desired.map(
          (ScheduledKayaNotification n) =>
              MapEntry<int, ScheduledKayaNotification>(n.id, n),
        ),
      );
  }

  @override
  Future<void> cancelAll() async {
    _scheduledById.clear();
  }

  @override
  List<ScheduledKayaNotification> get activeScheduledSnapshot {
    final List<ScheduledKayaNotification> list = _scheduledById.values.toList()
      ..sort(
        (ScheduledKayaNotification a, ScheduledKayaNotification b) =>
            a.scheduledAt.compareTo(b.scheduledAt),
      );
    return List<ScheduledKayaNotification>.unmodifiable(list);
  }
}
