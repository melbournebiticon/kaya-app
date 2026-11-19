import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:kaya/features/notifications/domain/local_notification_gateway.dart';
import 'package:kaya/features/notifications/domain/notification_models.dart';
import 'package:kaya/features/notifications/domain/notification_schedule_engine.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';
import 'package:material_ui/material_ui.dart';

/// Application controller for Phase 10 Notifications & Automation.
///
/// Enforces:
/// - Per-user isolated [NotificationPreferences].
/// - Explicit permission checks before scheduling.
/// - Immediate cancellation of all scheduled alerts on disable or logout.
/// - Automatic deduplicated re-sync when tasks, bills, documents, or routines change.
class NotificationController extends ChangeNotifier {
  NotificationController({
    required this.gateway,
    this.taskController,
    this.billController,
    this.reminderController,
    this.lifeVaultController,
    this.lifeOrganizationController,
    DateTime Function()? clock,
    String? initialUserId,
  }) : _clock = clock ?? DateTime.now,
       _activeUserId = (initialUserId?.trim().isEmpty ?? true)
           ? null
           : initialUserId!.trim() {
    final List<Listenable> listenables = <Listenable>[
      ?taskController,
      ?billController,
      ?reminderController,
      ?lifeVaultController,
      ?lifeOrganizationController,
    ];
    if (listenables.isNotEmpty) {
      _mergedSources = Listenable.merge(listenables);
      _mergedSources!.addListener(_handleDataChanged);
    }
  }

  final LocalNotificationGateway gateway;
  final TaskController? taskController;
  final BillController? billController;
  final ReminderController? reminderController;
  final LifeVaultController? lifeVaultController;
  final LifeOrganizationController? lifeOrganizationController;
  final DateTime Function() _clock;

  Listenable? _mergedSources;
  String? _activeUserId;
  int _userEpoch = 0;
  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;
  bool _isSyncing = false;

  final Map<String, NotificationPreferences> _preferencesByUser =
      <String, NotificationPreferences>{};
  List<ScheduledKayaNotification> _scheduled =
      const <ScheduledKayaNotification>[];

  String? get activeUserId => _activeUserId;
  NotificationPermissionStatus get permissionStatus => _permissionStatus;
  bool get isPermissionGranted =>
      _permissionStatus == NotificationPermissionStatus.granted;
  bool get isSyncing => _isSyncing;

  NotificationPreferences get preferences {
    final String? uid = _activeUserId;
    if (uid == null) {
      return const NotificationPreferences();
    }
    return _preferencesByUser[uid] ?? const NotificationPreferences();
  }

  List<ScheduledKayaNotification> get scheduledNotifications =>
      List<ScheduledKayaNotification>.unmodifiable(_scheduled);

  void _handleDataChanged() {
    syncNow();
  }

  @override
  void dispose() {
    _mergedSources?.removeListener(_handleDataChanged);
    _mergedSources = null;
    super.dispose();
  }

  /// Binds notification scheduling strictly to [userId].
  ///
  /// On logout (`null`) or account switch, cancels all previously scheduled
  /// local notifications immediately so no other user's alerts can fire.
  Future<void> bindAuthenticatedUser(String? userId) async {
    final String? normalized = (userId?.trim().isEmpty ?? true)
        ? null
        : userId!.trim();
    if (_activeUserId == normalized) {
      return;
    }

    _userEpoch++;
    _activeUserId = normalized;
    _scheduled = const <ScheduledKayaNotification>[];
    await gateway.cancelAll();

    if (normalized == null) {
      notifyListeners();
      return;
    }

    _permissionStatus = await gateway.checkPermission();
    await syncNow();
  }

  Future<NotificationPermissionStatus> requestPermission() async {
    final int requestEpoch = _userEpoch;
    final NotificationPermissionStatus result = await gateway
        .requestPermission();
    if (requestEpoch != _userEpoch) {
      return _permissionStatus;
    }
    _permissionStatus = result;
    await syncNow();
    return result;
  }

  Future<void> updatePreferences(NotificationPreferences next) async {
    final String? uid = _activeUserId;
    if (uid == null) {
      return;
    }
    _preferencesByUser[uid] = next;
    await syncNow();
  }

  Future<void> syncNow() async {
    final String? uid = _activeUserId;
    final int requestEpoch = _userEpoch;
    _isSyncing = true;
    notifyListeners();

    try {
      _permissionStatus = await gateway.checkPermission();
      if (requestEpoch != _userEpoch) {
        return;
      }

      if (uid == null ||
          !isPermissionGranted ||
          !preferences.notificationsEnabled) {
        await gateway.cancelAll();
        if (requestEpoch != _userEpoch) {
          return;
        }
        _scheduled = const <ScheduledKayaNotification>[];
        return;
      }

      final List<TaskItem> tasks =
          taskController != null && taskController!.activeUserId == uid
          ? taskController!.allTasks
          : const <TaskItem>[];
      final List<BillItem> bills =
          billController != null && billController!.activeUserId == uid
          ? billController!.allBills
          : const <BillItem>[];
      final List<ReminderItem> reminders =
          reminderController != null && reminderController!.activeUserId == uid
          ? reminderController!.allReminders
          : const <ReminderItem>[];
      final List<VaultDocument> docs =
          lifeVaultController != null &&
              lifeVaultController!.activeUserId == uid
          ? lifeVaultController!.allDocuments
          : const <VaultDocument>[];
      final List<DailyRoutine> routines =
          lifeOrganizationController != null &&
              lifeOrganizationController!.activeUserId == uid
          ? lifeOrganizationController!.routines
          : const <DailyRoutine>[];

      final List<ScheduledKayaNotification> desired =
          NotificationScheduleEngine.buildSchedule(
            userId: uid,
            preferences: preferences,
            now: _clock(),
            tasks: tasks,
            bills: bills,
            reminders: reminders,
            documents: docs,
            routines: routines,
          );

      await gateway.syncScheduledNotifications(desired: desired);
      if (requestEpoch != _userEpoch) {
        return;
      }
      _scheduled = gateway.activeScheduledSnapshot;
    } finally {
      if (requestEpoch == _userEpoch) {
        _isSyncing = false;
        notifyListeners();
      }
    }
  }
}
