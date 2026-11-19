import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/notifications/application/notification_controller.dart';
import 'package:kaya/features/notifications/domain/local_notification_gateway.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Phase 10 Notifications Settings & Permission Widget Tests', () {
    testWidgets(
      'requests notification permission, displays scheduled alerts, and cancels when disabled',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 980);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime(2026, 11, 16, 7, 30);
        final TaskController taskCtrl = TaskController(
          repository: InMemoryTaskRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p10_ui',
        );
        await taskCtrl.loadTasks();
        await taskCtrl.createTask(
          title: 'Renew NBI',
          dueDate: const KayaDateOnly(2026, 11, 16),
        );

        final NotificationController notifCtrl = NotificationController(
          gateway: InMemoryLocalNotificationGateway(),
          taskController: taskCtrl,
          clock: () => fixedNow,
          initialUserId: 'usr_p10_ui',
        );

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            taskController: taskCtrl,
            notificationController: notifCtrl,
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Settings tab.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Settings'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Notifications & Automation'), findsOneWidget);
        expect(find.text('0 scheduled alerts active'), findsOneWidget);

        // Request permission via Allow Notifications button.
        final Finder allowBtn = find.byKey(
          const ValueKey<String>('notifications_request_permission_button'),
        );
        await tester.ensureVisible(allowBtn);
        await tester.pumpAndSettle();
        await tester.tap(allowBtn);
        await tester.pumpAndSettle();

        expect(find.text('Allowed'), findsOneWidget);
        expect(find.text('1 scheduled alert active'), findsOneWidget);

        // Disable master switch -> cancels scheduled alerts immediately.
        final Finder masterSwitch = find.byKey(
          const ValueKey<String>('notifications_master_switch'),
        );
        await tester.ensureVisible(masterSwitch);
        await tester.pumpAndSettle();
        await tester.tap(masterSwitch);
        await tester.pumpAndSettle();

        expect(find.text('0 scheduled alerts active'), findsOneWidget);

        notifCtrl.dispose();
        taskCtrl.dispose();
      },
    );
  });
}
