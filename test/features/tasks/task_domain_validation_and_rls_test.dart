import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/task_validators.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';

void main() {
  group('KayaDateOnly & TaskValidators Boundary Tests (Sections 5 & 6)', () {
    test('KayaDateOnly parses valid dates, rejects invalid calendar dates, and computes day diffs', () {
      expect(
        KayaDateOnly.tryParse('2026-11-14'),
        const KayaDateOnly(2026, 11, 14),
      );
      expect(KayaDateOnly.tryParse('2026-02-30'), isNull);
      expect(KayaDateOnly.tryParse('not-a-date'), isNull);

      const KayaDateOnly today = KayaDateOnly(2026, 11, 14);
      const KayaDateOnly tomorrow = KayaDateOnly(2026, 11, 15);
      const KayaDateOnly yesterday = KayaDateOnly(2026, 11, 13);

      expect(tomorrow.daysDifferenceFrom(today), 1);
      expect(yesterday.daysDifferenceFrom(today), -1);
      expect(yesterday.isBefore(today), isTrue);
      expect(tomorrow.isAfter(today), isTrue);
      expect(today.isSameDay(const KayaDateOnly(2026, 11, 14)), isTrue);
    });

    test('TaskValidators enforce title, notes, and date boundaries', () {
      expect(TaskValidators.validateTitle(null), isNotNull);
      expect(TaskValidators.validateTitle('   '), isNotNull);
      expect(TaskValidators.validateTitle('A'), isNull);
      expect(TaskValidators.validateTitle('A' * 140), isNull);
      expect(TaskValidators.validateTitle('A' * 141), isNotNull);

      expect(TaskValidators.validateNotes(''), isNull);
      expect(TaskValidators.validateNotes('N' * 1000), isNull);
      expect(TaskValidators.validateNotes('N' * 1001), isNotNull);

      expect(TaskValidators.validateDueDate(null), isNull);
      expect(
        TaskValidators.validateDueDate(const KayaDateOnly(1999, 12, 31)),
        isNotNull,
      );
      expect(
        TaskValidators.validateDueDate(const KayaDateOnly(2000, 1, 1)),
        isNull,
      );
      expect(
        TaskValidators.validateDueDate(const KayaDateOnly(2100, 12, 31)),
        isNull,
      );
      expect(
        TaskValidators.validateDueDate(const KayaDateOnly(2101, 1, 1)),
        isNotNull,
      );
    });
  });

  group('Phase 3 Task Ownership RLS Isolation & Controller Lifecycle', () {
    test('Cross-account RLS isolation: User B cannot read, update, complete, or delete User A tasks', () async {
      final InMemoryTaskRepository repo = InMemoryTaskRepository();

      // User A creates a private task
      final TaskItem aliceTask = await repo.createTask(
        authenticatedUserId: 'usr_alice',
        title: 'Renew passport',
        priority: TaskPriority.high,
        category: TaskCategory.personal,
        dueDate: const KayaDateOnly(2026, 11, 14),
      );

      // User B creates their own task
      await repo.createTask(
        authenticatedUserId: 'usr_bob',
        title: 'Buy groceries',
      );

      // 1. User B fetching only sees their own 1 task
      final List<TaskItem> bobTasks = await repo.fetchTasks(
        authenticatedUserId: 'usr_bob',
      );
      expect(bobTasks.length, 1);
      expect(bobTasks.single.title, 'Buy groceries');

      // 2. User B requesting Alice's owner ID is denied by RLS
      await expectLater(
        () => repo.fetchTasks(
          authenticatedUserId: 'usr_bob',
          requestedOwnerId: 'usr_alice',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure f) => f.code,
            'code',
            AuthFailureCode.unauthorizedAccess,
          ),
        ),
      );

      // 3. User B attempting to update Alice's task is denied
      await expectLater(
        () => repo.updateTask(
          authenticatedUserId: 'usr_bob',
          taskId: aliceTask.id,
          title: 'Tampered Title',
          notes: '',
          priority: TaskPriority.low,
          category: TaskCategory.other,
          dueDate: null,
        ),
        throwsA(isA<AuthFailure>()),
      );

      // 4. User B attempting to complete Alice's task is denied
      await expectLater(
        () => repo.setTaskCompleted(
          authenticatedUserId: 'usr_bob',
          taskId: aliceTask.id,
          isCompleted: true,
        ),
        throwsA(isA<AuthFailure>()),
      );

      // 5. User B attempting to delete Alice's task is denied
      await expectLater(
        () => repo.deleteTask(
          authenticatedUserId: 'usr_bob',
          taskId: aliceTask.id,
        ),
        throwsA(isA<AuthFailure>()),
      );

      // Verify Alice's task remains intact
      final List<TaskItem> aliceTasks = await repo.fetchTasks(
        authenticatedUserId: 'usr_alice',
      );
      expect(aliceTasks.single.title, 'Renew passport');
      expect(aliceTasks.single.isCompleted, isFalse);
    });

    test('TaskController accurately classifies Overdue/Today/Upcoming, ranks urgency, handles errors/retry, and clears on logout', () async {
      final DateTime fixedNow = DateTime.utc(2026, 11, 14, 9, 0);
      final InMemoryTaskRepository repo = InMemoryTaskRepository(
        clock: () => fixedNow,
      );
      final TaskController controller = TaskController(
        repository: repo,
        clock: () => fixedNow,
      );

      await controller.bindAuthenticatedUser('usr_1');
      expect(controller.loadStatus, TaskLoadStatus.loaded);
      expect(controller.allTasks, isEmpty);

      // Create Overdue, Today (Urgent), Today (Medium), and Upcoming tasks
      await controller.createTask(
        title: 'Upcoming project review',
        priority: TaskPriority.high,
        category: TaskCategory.work,
        dueDate: const KayaDateOnly(2026, 11, 20),
      );
      await controller.createTask(
        title: 'Today medium errand',
        priority: TaskPriority.medium,
        category: TaskCategory.errands,
        dueDate: const KayaDateOnly(2026, 11, 14),
      );
      await controller.createTask(
        title: 'Pay overdue utility bill',
        priority: TaskPriority.urgent,
        category: TaskCategory.finance,
        dueDate: const KayaDateOnly(2026, 11, 12),
      );

      expect(controller.overdueTasks.length, 1);
      expect(controller.todayTasks.length, 1);
      expect(controller.upcomingTasks.length, 1);
      expect(controller.todayPriorityQueue.length, 2);
      expect(controller.mostImportantTask?.title, 'Pay overdue utility bill');

      // Complete the overdue task -> moves to completedTasks
      final String overdueId = controller.overdueTasks.single.id;
      await controller.setTaskCompleted(taskId: overdueId, isCompleted: true);
      expect(controller.overdueTasks, isEmpty);
      expect(controller.completedTasks.length, 1);
      expect(controller.mostImportantTask?.title, 'Today medium errand');

      // Reopen the completed task
      await controller.setTaskCompleted(taskId: overdueId, isCompleted: false);
      expect(controller.overdueTasks.length, 1);
      expect(controller.completedTasks, isEmpty);

      // Simulate network error -> loadStatus is error (not treated as empty)
      repo.simulateNetworkFailure = true;
      await controller.loadTasks();
      expect(controller.hasLoadError, isTrue);

      // Restore network and retry
      repo.simulateNetworkFailure = false;
      await controller.loadTasks();
      expect(controller.hasLoadError, isFalse);
      expect(controller.allTasks.length, 3);

      // Logout -> bindAuthenticatedUser(null) clears all tasks immediately
      await controller.bindAuthenticatedUser(null);
      expect(controller.allTasks, isEmpty);
      expect(controller.loadStatus, TaskLoadStatus.idle);
    });
  });
}
