import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';
import 'package:kaya/features/tasks/domain/task_repository.dart';
import 'package:material_ui/material_ui.dart';

/// Loading status for task list queries.
///
/// Explicitly separates [error] from [loaded] with 0 items so failed queries
/// are never treated as empty data.
enum TaskLoadStatus { idle, loading, loaded, error }

/// Application state controller for Phase 3 Task Management.
class TaskController extends ChangeNotifier {
  TaskController({
    required this.repository,
    DateTime Function()? clock,
    String? initialUserId,
  }) : _clock = clock ?? DateTime.now,
       _activeUserId = initialUserId;

  final TaskRepository repository;
  final DateTime Function() _clock;

  String? _activeUserId;
  int _userEpoch = 0;
  TaskLoadStatus _loadStatus = TaskLoadStatus.idle;
  bool _isMutating = false;
  String? _errorMessage;

  final List<TaskItem> _tasks = <TaskItem>[];
  TaskFilterView _selectedView = TaskFilterView.all;
  TaskCategory? _selectedCategory;
  TaskPriority? _selectedPriority;
  String _searchQuery = '';

  String? get activeUserId => _activeUserId;
  TaskLoadStatus get loadStatus => _loadStatus;
  bool get isLoading => _loadStatus == TaskLoadStatus.loading;
  bool get hasLoadError => _loadStatus == TaskLoadStatus.error;
  bool get isMutating => _isMutating;
  String? get errorMessage => _errorMessage;

  TaskFilterView get selectedView => _selectedView;
  TaskCategory? get selectedCategory => _selectedCategory;
  TaskPriority? get selectedPriority => _selectedPriority;
  String get searchQuery => _searchQuery;

  KayaDateOnly get referenceToday => KayaDateOnly.fromDateTime(_clock());

  List<TaskItem> get allTasks {
    final List<TaskItem> copy = List<TaskItem>.from(_tasks);
    copy.sort(
      (TaskItem a, TaskItem b) =>
          TaskItem.compareByUrgency(a, b, referenceToday),
    );
    return List<TaskItem>.unmodifiable(copy);
  }

  List<TaskItem> get activeTasks =>
      allTasks.where((TaskItem t) => !t.isCompleted).toList(growable: false);

  List<TaskItem> get overdueTasks => allTasks
      .where((TaskItem t) => t.isOverdue(referenceToday))
      .toList(growable: false);

  List<TaskItem> get todayTasks => allTasks
      .where((TaskItem t) => t.isDueToday(referenceToday))
      .toList(growable: false);

  List<TaskItem> get upcomingTasks => allTasks
      .where((TaskItem t) => t.isUpcoming(referenceToday))
      .toList(growable: false);

  List<TaskItem> get completedTasks =>
      allTasks.where((TaskItem t) => t.isCompleted).toList(growable: false);

  /// Tasks due today or overdue, ordered by urgency for the Today overview.
  List<TaskItem> get todayPriorityQueue {
    final KayaDateOnly today = referenceToday;
    return allTasks
        .where((TaskItem t) => t.isOverdue(today) || t.isDueToday(today))
        .toList(growable: false);
  }

  /// Highest-urgency incomplete task (answers "What is my most important task?").
  TaskItem? get mostImportantTask {
    final List<TaskItem> incomplete = activeTasks;
    if (incomplete.isEmpty) {
      return null;
    }
    return incomplete.first;
  }

  /// Filtered and searched tasks matching the current UI view and filters.
  List<TaskItem> get filteredTasks {
    final KayaDateOnly today = referenceToday;
    final String normalizedSearch = _searchQuery.trim().toLowerCase();

    return allTasks
        .where((TaskItem task) {
          final bool matchesView = switch (_selectedView) {
            TaskFilterView.all => !task.isCompleted,
            TaskFilterView.today => task.isDueToday(today),
            TaskFilterView.upcoming => task.isUpcoming(today),
            TaskFilterView.overdue => task.isOverdue(today),
            TaskFilterView.completed => task.isCompleted,
          };
          if (!matchesView) {
            return false;
          }
          if (_selectedCategory != null && task.category != _selectedCategory) {
            return false;
          }
          if (_selectedPriority != null && task.priority != _selectedPriority) {
            return false;
          }
          if (normalizedSearch.isNotEmpty) {
            final bool inTitle = task.title.toLowerCase().contains(
              normalizedSearch,
            );
            final bool inNotes = task.notes.toLowerCase().contains(
              normalizedSearch,
            );
            if (!inTitle && !inNotes) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Binds the controller to the authenticated user, clearing private caches
  /// immediately on logout or account switch.
  Future<void> bindAuthenticatedUser(String? userId) async {
    final String? normalized = userId?.trim().isEmpty ?? true
        ? null
        : userId!.trim();
    if (_activeUserId == normalized && _loadStatus != TaskLoadStatus.idle) {
      return;
    }

    _userEpoch++;
    _activeUserId = normalized;
    _clearCachedTasksAndFilters();

    if (normalized == null) {
      _loadStatus = TaskLoadStatus.idle;
      notifyListeners();
      return;
    }

    await loadTasks();
  }

  void setFilterView(TaskFilterView view) {
    if (_selectedView != view) {
      _selectedView = view;
      notifyListeners();
    }
  }

  void setCategoryFilter(TaskCategory? category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  void setPriorityFilter(TaskPriority? priority) {
    if (_selectedPriority != priority) {
      _selectedPriority = priority;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  void clearFilters() {
    _selectedView = TaskFilterView.all;
    _selectedCategory = null;
    _selectedPriority = null;
    _searchQuery = '';
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Loads all tasks owned by the active authenticated user.
  Future<void> loadTasks() async {
    final String? uid = _activeUserId;
    if (uid == null) {
      _clearCachedTasksAndFilters();
      _loadStatus = TaskLoadStatus.idle;
      notifyListeners();
      return;
    }

    final int requestEpoch = ++_userEpoch;
    _loadStatus = TaskLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<TaskItem> loaded = await repository.fetchTasks(
        authenticatedUserId: uid,
      );
      if (requestEpoch != _userEpoch) {
        return;
      }
      _tasks
        ..clear()
        ..addAll(loaded);
      _loadStatus = TaskLoadStatus.loaded;
    } on AuthFailure catch (failure) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage = failure.message;
      _loadStatus = TaskLoadStatus.error;
    } catch (_) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage =
          'Unable to load tasks. Please check your connection and try again.';
      _loadStatus = TaskLoadStatus.error;
    }
    notifyListeners();
  }

  /// Creates a new task after server confirmation.
  Future<bool> createTask({
    required String title,
    String notes = '',
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.personal,
    KayaDateOnly? dueDate,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final TaskItem created = await repository.createTask(
        authenticatedUserId: uid,
        title: title,
        notes: notes,
        priority: priority,
        category: category,
        dueDate: dueDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _tasks.add(created);
      _loadStatus = TaskLoadStatus.loaded;
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to create task. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Updates an existing task after server confirmation.
  Future<bool> updateTask({
    required String taskId,
    required String title,
    required String notes,
    required TaskPriority priority,
    required TaskCategory category,
    required KayaDateOnly? dueDate,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final TaskItem updated = await repository.updateTask(
        authenticatedUserId: uid,
        taskId: taskId,
        title: title,
        notes: notes,
        priority: priority,
        category: category,
        dueDate: dueDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _tasks.indexWhere((TaskItem t) => t.id == taskId);
      if (idx != -1) {
        _tasks[idx] = updated;
      }
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to update task. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Completes or reopens a task after server confirmation.
  Future<bool> setTaskCompleted({
    required String taskId,
    required bool isCompleted,
  }) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final TaskItem updated = await repository.setTaskCompleted(
        authenticatedUserId: uid,
        taskId: taskId,
        isCompleted: isCompleted,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _tasks.indexWhere((TaskItem t) => t.id == taskId);
      if (idx != -1) {
        _tasks[idx] = updated;
      }
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to update task status. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Deletes a task after server confirmation.
  Future<bool> deleteTask(String taskId) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteTask(authenticatedUserId: uid, taskId: taskId);
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _tasks.removeWhere((TaskItem t) => t.id == taskId);
      _isMutating = false;
      notifyListeners();
      return true;
    } on AuthFailure catch (failure) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = failure.message;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    } catch (_) {
      if (requestEpoch == _userEpoch) {
        _errorMessage = 'Failed to delete task. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  void _clearCachedTasksAndFilters() {
    _tasks.clear();
    _selectedView = TaskFilterView.all;
    _selectedCategory = null;
    _selectedPriority = null;
    _searchQuery = '';
    _errorMessage = null;
    _isMutating = false;
  }
}
