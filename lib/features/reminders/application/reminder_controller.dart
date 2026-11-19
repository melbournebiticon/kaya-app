import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/reminders/domain/reminder_repository.dart';
import 'package:material_ui/material_ui.dart';

/// Loading status for reminders queries.
enum ReminderLoadStatus { idle, loading, loaded, error }

/// Application state controller for Phase 5 Reminders Management.
class ReminderController extends ChangeNotifier {
  ReminderController({
    required this.repository,
    DateTime Function()? clock,
    String? initialUserId,
  }) : _clock = clock ?? DateTime.now,
       _activeUserId = initialUserId;

  final ReminderRepository repository;
  final DateTime Function() _clock;

  String? _activeUserId;
  int _userEpoch = 0;

  ReminderLoadStatus _loadStatus = ReminderLoadStatus.idle;
  bool _isMutating = false;
  String? _errorMessage;

  final List<ReminderItem> _reminders = <ReminderItem>[];
  ReminderFilterView _selectedView = ReminderFilterView.active;
  String _searchQuery = '';

  String? get activeUserId => _activeUserId;
  ReminderLoadStatus get loadStatus => _loadStatus;
  bool get isLoading => _loadStatus == ReminderLoadStatus.loading;
  bool get hasLoadError => _loadStatus == ReminderLoadStatus.error;
  bool get isMutating => _isMutating;
  String? get errorMessage => _errorMessage;

  ReminderFilterView get selectedView => _selectedView;
  String get searchQuery => _searchQuery;

  KayaDateOnly get referenceToday => KayaDateOnly.fromDateTime(_clock());

  List<ReminderItem> get allReminders {
    final List<ReminderItem> copy = List<ReminderItem>.from(_reminders);
    copy.sort(
      (ReminderItem a, ReminderItem b) =>
          ReminderItem.compareByUrgency(a, b, referenceToday),
    );
    return List<ReminderItem>.unmodifiable(copy);
  }

  List<ReminderItem> get activeReminders => allReminders
      .where((ReminderItem r) => !r.isCompleted)
      .toList(growable: false);

  List<ReminderItem> get overdueReminders => allReminders
      .where((ReminderItem r) => r.isOverdue(referenceToday))
      .toList(growable: false);

  List<ReminderItem> get todayReminders => allReminders
      .where((ReminderItem r) => r.isDueToday(referenceToday))
      .toList(growable: false);

  List<ReminderItem> get upcomingReminders => allReminders
      .where((ReminderItem r) => r.isUpcoming(referenceToday))
      .toList(growable: false);

  List<ReminderItem> get completedReminders => allReminders
      .where((ReminderItem r) => r.isCompleted)
      .toList(growable: false);

  List<ReminderItem> get todayPriorityReminders {
    final KayaDateOnly today = referenceToday;
    return allReminders
        .where((ReminderItem r) => r.isOverdue(today) || r.isDueToday(today))
        .toList(growable: false);
  }

  List<ReminderItem> get filteredReminders {
    final KayaDateOnly today = referenceToday;
    final String normalizedSearch = _searchQuery.trim().toLowerCase();

    return allReminders
        .where((ReminderItem r) {
          final bool matchesView = switch (_selectedView) {
            ReminderFilterView.active => !r.isCompleted,
            ReminderFilterView.overdue => r.isOverdue(today),
            ReminderFilterView.today => r.isDueToday(today),
            ReminderFilterView.upcoming => r.isUpcoming(today),
            ReminderFilterView.completed => r.isCompleted,
          };
          if (!matchesView) {
            return false;
          }
          if (normalizedSearch.isNotEmpty) {
            final bool inTitle = r.title.toLowerCase().contains(
              normalizedSearch,
            );
            final bool inNotes = r.notes.toLowerCase().contains(
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

  Future<void> bindAuthenticatedUser(String? userId) async {
    final String? normalized = (userId?.trim().isEmpty ?? true)
        ? null
        : userId!.trim();
    if (_activeUserId == normalized && _loadStatus != ReminderLoadStatus.idle) {
      return;
    }

    _userEpoch++;
    _activeUserId = normalized;
    _clearPrivateCaches();

    if (normalized == null) {
      _loadStatus = ReminderLoadStatus.idle;
      notifyListeners();
      return;
    }

    await loadReminders();
  }

  void setFilterView(ReminderFilterView view) {
    if (_selectedView != view) {
      _selectedView = view;
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
    _selectedView = ReminderFilterView.active;
    _searchQuery = '';
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> loadReminders() async {
    final String? uid = _activeUserId;
    if (uid == null) {
      _clearPrivateCaches();
      _loadStatus = ReminderLoadStatus.idle;
      notifyListeners();
      return;
    }

    final int requestEpoch = ++_userEpoch;
    _loadStatus = ReminderLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<ReminderItem> loaded = await repository.fetchReminders(
        authenticatedUserId: uid,
      );
      if (requestEpoch != _userEpoch) {
        return;
      }
      _reminders
        ..clear()
        ..addAll(loaded);
      _loadStatus = ReminderLoadStatus.loaded;
    } on AuthFailure catch (failure) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage = failure.message;
      _loadStatus = ReminderLoadStatus.error;
    } catch (_) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage = 'Unable to load reminders. Please check your connection and try again.';
      _loadStatus = ReminderLoadStatus.error;
    }
    notifyListeners();
  }

  Future<bool> createReminder({
    required String title,
    String notes = '',
    required KayaDateOnly dueDate,
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
      final ReminderItem created = await repository.createReminder(
        authenticatedUserId: uid,
        title: title,
        notes: notes,
        dueDate: dueDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _reminders.add(created);
      _loadStatus = ReminderLoadStatus.loaded;
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
        _errorMessage = 'Failed to create reminder. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> updateReminder({
    required String reminderId,
    required String title,
    required String notes,
    required KayaDateOnly dueDate,
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
      final ReminderItem updated = await repository.updateReminder(
        authenticatedUserId: uid,
        reminderId: reminderId,
        title: title,
        notes: notes,
        dueDate: dueDate,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _reminders.indexWhere(
        (ReminderItem r) => r.id == reminderId,
      );
      if (idx != -1) {
        _reminders[idx] = updated;
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
        _errorMessage = 'Failed to update reminder. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> setReminderCompleted({
    required String reminderId,
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
      final ReminderItem updated = await repository.setReminderCompleted(
        authenticatedUserId: uid,
        reminderId: reminderId,
        isCompleted: isCompleted,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      final int idx = _reminders.indexWhere(
        (ReminderItem r) => r.id == reminderId,
      );
      if (idx != -1) {
        _reminders[idx] = updated;
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
        _errorMessage = 'Failed to update reminder status. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> deleteReminder(String reminderId) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }

    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteReminder(
        authenticatedUserId: uid,
        reminderId: reminderId,
      );
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _reminders.removeWhere((ReminderItem r) => r.id == reminderId);
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
        _errorMessage = 'Failed to delete reminder. Please try again.';
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  void _clearPrivateCaches() {
    _reminders.clear();
    _selectedView = ReminderFilterView.active;
    _searchQuery = '';
    _errorMessage = null;
    _isMutating = false;
  }
}
