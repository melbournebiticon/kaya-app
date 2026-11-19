import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Phase 9 AI Integration Widget & Confirmed Task Creation Tests', () {
    testWidgets(
      'enables optional AI, opens privacy consent dialog, receives task plan, and adds task only after confirmation',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 980);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 9, 0);
        final TaskController taskCtrl = TaskController(
          repository: InMemoryTaskRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_p9_ui',
        );
        await taskCtrl.loadTasks();

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            taskController: taskCtrl,
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Assistant tab.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Assistant'),
          ),
        );
        await tester.pumpAndSettle();

        // Toggle optional AI Assist ON.
        await tester.tap(
          find.byKey(const ValueKey<String>('assistant_ai_mode_switch')),
        );
        await tester.pumpAndSettle();
        expect(find.text('AI Assist ON (0/25 today)'), findsOneWidget);

        // Open Privacy & Limits dialog and opt in to Financial Summary.
        await tester.tap(
          find.byKey(const ValueKey<String>('assistant_privacy_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('AI Privacy & Usage Limits'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey<String>('ai_consent_financial_switch')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('ai_consent_save_button')),
        );
        await tester.pumpAndSettle();

        // Ask AI to plan today's tasks.
        await tester.enterText(
          find.byKey(const ValueKey<String>('assistant_prompt_input')),
          'Help me plan my tasks today.',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('assistant_send_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('AI Assisted'), findsOneWidget);
        expect(
          find.text('Suggested Tasks (confirmation required)'),
          findsOneWidget,
        );
        expect(taskCtrl.allTasks, isEmpty);

        // Confirm first suggested task via KayaConfirmDialog.
        final Finder confirmBtn = find.byKey(
          const ValueKey<String>('ai_confirm_task_plan_step_1'),
        );
        await tester.ensureVisible(confirmBtn);
        await tester.pumpAndSettle();
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(find.text('Add Suggested Task?'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
        await tester.pumpAndSettle();

        expect(taskCtrl.allTasks.length, 1);
        expect(find.text('Added'), findsOneWidget);

        taskCtrl.dispose();
      },
    );
  });
}
