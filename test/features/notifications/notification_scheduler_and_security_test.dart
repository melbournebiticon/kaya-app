import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/data/in_memory_bill_repository.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/data/in_memory_life_vault_repository.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/notifications/application/notification_controller.dart';
import 'package:kaya/features/notifications/domain/local_notification_gateway.dart';
import 'package:kaya/features/notifications/domain/notification_models.dart';
import 'package:kaya/features/notifications/domain/notification_schedule_engine.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/data/in_memory_life_organization_repository.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';

void main() {
  group('QuietHoursWindow & Deterministic Scheduling', () {
    test(
      'defers overnight and daytime quiet-hour notifications accurately',
      () {
        const QuietHoursWindow overnight = QuietHoursWindow(
          enabled: true,
          startHour: 22,
          startMinute: 0,
          endHour: 7,
          endMinute: 0,
        );

        // 23:30 shifts to next morning 07:00.
        expect(
          overnight.adjustForQuietHours(DateTime(2026, 11, 16, 23, 30)),
          DateTime(2026, 11, 17, 7, 0),
        );
        // 05:15 shifts to same day 07:00.
        expect(
          overnight.adjustForQuietHours(DateTime(2026, 11, 16, 5, 15)),
          DateTime(2026, 11, 16, 7, 0),
        );
        // 09:00 stays unchanged.
        expect(
          overnight.adjustForQuietHours(DateTime(2026, 11, 16, 9, 0)),
          DateTime(2026, 11, 16, 9, 0),
        );

        const QuietHoursWindow midday = QuietHoursWindow(
          enabled: true,
          startHour: 13,
          startMinute: 0,
          endHour: 15,
          endMinute: 0,
        );
        expect(
          midday.adjustForQuietHours(DateTime(2026, 11, 16, 13, 45)),
          DateTime(2026, 11, 16, 15, 0),
        );
      },
    );

    test('schedules tasks, unpaid bills, expiring docs, and recurring routines with zero duplicates and safe privacy', () async {
      final DateTime fixedNow = DateTime(2026, 11, 16, 7, 30);
      const KayaDateOnly today = KayaDateOnly(2026, 11, 16);

      final TaskController taskCtrl = TaskController(
        repository: InMemoryTaskRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_notif',
      );
      final BillController billCtrl = BillController(
        repository: InMemoryBillRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_notif',
        initialCurrency: SupportedCurrency.php,
      );
      final LifeVaultController vaultCtrl = LifeVaultController(
        repository: InMemoryLifeVaultRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_notif',
      );
      final LifeOrganizationController orgCtrl = LifeOrganizationController(
        repository: InMemoryLifeOrganizationRepository(clock: () => fixedNow),
        clock: () => fixedNow,
        initialUserId: 'usr_notif',
      );

      await taskCtrl.loadTasks();
      await billCtrl.loadBills();
      await vaultCtrl.loadVault();
      await orgCtrl.loadAll();

      await taskCtrl.createTask(
        title: 'Submit Report',
        priority: TaskPriority.high,
        dueDate: today,
      );
      await taskCtrl.createTask(
        title: 'Completed Task',
        dueDate: today.addDays(1),
      );
      final String completedId = taskCtrl.allTasks
          .firstWhere((t) => t.title == 'Completed Task')
          .id;
      await taskCtrl.setTaskCompleted(taskId: completedId, isCompleted: true);

      await billCtrl.createBill(
        title: 'Fiber Internet',
        amountMinor: 169900,
        dueDate: today.addDays(4),
      );
      await billCtrl.createBill(
        title: 'Paid Water Bill',
        amountMinor: 50000,
        dueDate: today.addDays(2),
      );
      final String paidBillId = billCtrl.allBills
          .firstWhere((b) => b.title == 'Paid Water Bill')
          .id;
      await billCtrl.setBillPaid(billId: paidBillId, isPaid: true);

      await vaultCtrl.createDocument(
        title: 'Passport',
        category: DocumentCategory.passportVisa,
        physicalLocation: 'SECRET_SAFE_BOX',
        notes: 'SECRET_DOC_NOTE',
        expirationDate: today.addDays(20),
      );

      await orgCtrl.createRoutine(
        title: 'Morning Walk',
        scheduledWeekdays: const <int>{1, 3}, // Mon, Wed
        initialSteps: const <String>['Walk 20m'],
      );

      final InMemoryLocalNotificationGateway gateway =
          InMemoryLocalNotificationGateway(
            initialPermission: NotificationPermissionStatus.notDetermined,
          );
      final NotificationController notifCtrl = NotificationController(
        gateway: gateway,
        taskController: taskCtrl,
        billController: billCtrl,
        lifeVaultController: vaultCtrl,
        lifeOrganizationController: orgCtrl,
        clock: () => fixedNow,
        initialUserId: 'usr_notif',
      );

      // Before permission granted -> nothing scheduled.
      await notifCtrl.syncNow();
      expect(notifCtrl.scheduledNotifications, isEmpty);

      // Grant permission -> schedules 1 task + 2 bill alerts (advance + due) + 2 doc alerts + 2 routine weekdays = 7.
      final NotificationPermissionStatus perm = await notifCtrl
          .requestPermission();
      expect(perm, NotificationPermissionStatus.granted);
      expect(notifCtrl.scheduledNotifications.length, 7);

      // Re-sync multiple times -> zero duplicates, identical IDs!
      final List<int> idsFirst = notifCtrl.scheduledNotifications
          .map((ScheduledKayaNotification n) => n.id)
          .toList();
      await notifCtrl.syncNow();
      await notifCtrl.syncNow();
      final List<int> idsAfter = notifCtrl.scheduledNotifications
          .map((ScheduledKayaNotification n) => n.id)
          .toList();
      expect(idsAfter, idsFirst);
      expect(idsAfter.toSet().length, idsAfter.length);

      // Paid bills, completed tasks, and vault secrets MUST NOT appear.
      final String allBodies = notifCtrl.scheduledNotifications
          .map((ScheduledKayaNotification n) => n.body)
          .join('\n');
      expect(allBodies, contains('Submit Report'));
      expect(allBodies, contains('Fiber Internet'));
      expect(allBodies, contains('Passport'));
      expect(allBodies, contains('Morning Walk'));
      expect(allBodies, isNot(contains('Completed Task')));
      expect(allBodies, isNot(contains('Paid Water Bill')));
      expect(allBodies, isNot(contains('SECRET_SAFE_BOX')));
      expect(allBodies, isNot(contains('SECRET_DOC_NOTE')));

      // Disabling notifications cancels all scheduled alerts immediately.
      await notifCtrl.updatePreferences(
        notifCtrl.preferences.copyWith(notificationsEnabled: false),
      );
      expect(notifCtrl.scheduledNotifications, isEmpty);
      expect(gateway.activeScheduledSnapshot, isEmpty);

      // Re-enable, then logout cancels all alerts and isolates user preferences.
      await notifCtrl.updatePreferences(
        notifCtrl.preferences.copyWith(notificationsEnabled: true),
      );
      expect(notifCtrl.scheduledNotifications, isNotEmpty);

      await notifCtrl.bindAuthenticatedUser(null);
      expect(notifCtrl.scheduledNotifications, isEmpty);
      expect(gateway.activeScheduledSnapshot, isEmpty);

      // Stable ID sanity check.
      expect(
        NotificationScheduleEngine.stableNotificationId('same_key'),
        NotificationScheduleEngine.stableNotificationId('same_key'),
      );

      notifCtrl.dispose();
      orgCtrl.dispose();
      vaultCtrl.dispose();
      billCtrl.dispose();
      taskCtrl.dispose();
    });
  });
}
