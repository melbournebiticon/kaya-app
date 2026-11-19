import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Phase 3 Task Management UI & Today Integration Tests', () {
    testWidgets(
      'creates task via Quick Add, guards completion against accidental taps, and manages full lifecycle in Life tab',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime.utc(2026, 11, 14, 10, 0);
        final InMemoryTaskRepository repo = InMemoryTaskRepository(
          clock: () => fixedNow,
        );
        final TaskController taskController = TaskController(
          repository: repo,
          clock: () => fixedNow,
          initialUserId: 'usr_qa',
        );
        await taskController.loadTasks();

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            taskController: taskController,
          ),
        );
        await tester.pumpAndSettle();

        // Initially no priorities scheduled for today
        expect(find.text('No Priorities Scheduled for Today'), findsOneWidget);

        // Quick Add a task on Today screen
        await tester.enterText(
          find.byKey(const ValueKey<String>('quick_add_task_field')),
          'Submit quarterly tax return',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('quick_add_submit_button')),
        );
        await tester.pumpAndSettle();

        // Task now appears as Most Important Task and in Today's Priority Queue
        expect(find.text('Most Important Task'), findsOneWidget);
        expect(find.text('Submit quarterly tax return'), findsWidgets);

        // Switch to Life module
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Life'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Task Management'), findsOneWidget);
        expect(find.text('Today: 1'), findsOneWidget);

        // Filter by Search query
        await tester.enterText(
          find.byKey(const ValueKey<String>('task_search_field')),
          'nonexistent_query',
        );
        await tester.pumpAndSettle();
        expect(find.text('No Matching Tasks Found'), findsOneWidget);

        // Clear search
        await tester.enterText(
          find.byKey(const ValueKey<String>('task_search_field')),
          '',
        );
        await tester.pumpAndSettle();
        expect(find.text('Submit quarterly tax return'), findsOneWidget);

        // Tap complete toggle -> opens confirmation dialog instead of completing immediately
        final String taskId = taskController.allTasks.single.id;
        await tester.ensureVisible(
          find.byKey(ValueKey<String>('task_toggle_$taskId')),
        );
        await tester.tap(find.byKey(ValueKey<String>('task_toggle_$taskId')));
        await tester.pumpAndSettle();

        expect(find.text('Complete Task?'), findsOneWidget);

        // Cancel accidental tap -> task stays active
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Completed: 0'), findsOneWidget);
        expect(taskController.allTasks.single.isCompleted, isFalse);

        // Tap complete toggle again and confirm
        await tester.ensureVisible(
          find.byKey(ValueKey<String>('task_toggle_$taskId')),
        );
        await tester.tap(find.byKey(ValueKey<String>('task_toggle_$taskId')));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Mark Completed'));
        await tester.pumpAndSettle();

        expect(find.text('Completed: 1'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);

        // Switch to Completed tab to view and delete the completed task
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('task_view_tab_completed')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('task_view_tab_completed')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Submit quarterly tax return'), findsOneWidget);

        // Delete the task (confirms via KayaConfirmDialog)
        await tester.ensureVisible(
          find.byKey(ValueKey<String>('task_delete_$taskId')),
        );
        await tester.tap(find.byKey(ValueKey<String>('task_delete_$taskId')));
        await tester.pumpAndSettle();
        expect(find.text('Delete Task?'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Task'));
        await tester.pumpAndSettle();
        expect(taskController.allTasks, isEmpty);
      },
    );

    testWidgets(
      'warns before completing an upcoming task early and supports Undo via SnackBar',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime.utc(2026, 11, 14, 10, 0);
        final InMemoryTaskRepository repo = InMemoryTaskRepository(
          clock: () => fixedNow,
        );
        final TaskController taskController = TaskController(
          repository: repo,
          clock: () => fixedNow,
          initialUserId: 'usr_qa',
        );
        await taskController.loadTasks();
        await taskController.createTask(
          title: 'Renew vehicle registration',
          dueDate: const KayaDateOnly(2026, 11, 15),
        );

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            taskController: taskController,
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Life module
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Life'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Upcoming: 1'), findsOneWidget);
        final String upcomingId = taskController.upcomingTasks.single.id;

        // Tap complete toggle on upcoming task -> shows early completion warning
        await tester.ensureVisible(
          find.byKey(ValueKey<String>('task_toggle_$upcomingId')),
        );
        await tester.tap(
          find.byKey(ValueKey<String>('task_toggle_$upcomingId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Complete Upcoming Task Early?'), findsOneWidget);
        expect(
          find.textContaining('scheduled for Nov 15, 2026 (Due Tomorrow)'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(ElevatedButton, 'Complete Early'),
          findsOneWidget,
        );

        // Confirm early completion
        await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Early'));
        await tester.pumpAndSettle();

        expect(find.text('Completed: 1'), findsOneWidget);
        expect(find.text('Upcoming: 0'), findsOneWidget);
        expect(taskController.allTasks.single.isCompleted, isTrue);

        // Tap Undo on SnackBar -> task returns to active upcoming tasks
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        expect(find.text('Completed: 0'), findsOneWidget);
        expect(find.text('Upcoming: 1'), findsOneWidget);
        expect(taskController.upcomingTasks.single.isCompleted, isFalse);
      },
    );
  });
}
