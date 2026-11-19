import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/checklists/domain/smart_checklist.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/routines/domain/life_organization_repository.dart';
import 'package:kaya/features/shopping/domain/shopping_list.dart';
import 'package:material_ui/material_ui.dart';

/// Loading status for Life Organization queries.
enum LifeOrganizationLoadStatus { idle, loading, loaded, error }

/// Unified application controller for Phase 7 Life Organization:
/// Smart Checklists, Daily Routines, and Shopping Lists.
class LifeOrganizationController extends ChangeNotifier {
  LifeOrganizationController({
    required this.repository,
    DateTime Function()? clock,
    String? initialUserId,
    SupportedCurrency initialCurrency = SupportedCurrency.php,
  }) : _clock = clock ?? DateTime.now,
       _activeUserId = initialUserId,
       _activeCurrency = initialCurrency;

  final LifeOrganizationRepository repository;
  final DateTime Function() _clock;

  String? _activeUserId;
  SupportedCurrency _activeCurrency;
  int _userEpoch = 0;

  LifeOrganizationLoadStatus _loadStatus = LifeOrganizationLoadStatus.idle;
  bool _isMutating = false;
  String? _errorMessage;

  final List<SmartChecklist> _checklists = <SmartChecklist>[];
  final List<DailyRoutine> _routines = <DailyRoutine>[];
  final List<ShoppingList> _shoppingLists = <ShoppingList>[];

  String? get activeUserId => _activeUserId;
  SupportedCurrency get activeCurrency => _activeCurrency;
  LifeOrganizationLoadStatus get loadStatus => _loadStatus;
  bool get isLoading => _loadStatus == LifeOrganizationLoadStatus.loading;
  bool get hasLoadError => _loadStatus == LifeOrganizationLoadStatus.error;
  bool get isMutating => _isMutating;
  String? get errorMessage => _errorMessage;

  KayaDateOnly get referenceToday => KayaDateOnly.fromDateTime(_clock());

  List<SmartChecklist> get checklists =>
      List<SmartChecklist>.unmodifiable(_checklists);

  List<DailyRoutine> get routines => List<DailyRoutine>.unmodifiable(_routines);

  List<DailyRoutine> get todayScheduledRoutines {
    final KayaDateOnly today = referenceToday;
    return _routines
        .where((DailyRoutine r) => r.isScheduledOn(today))
        .toList(growable: false);
  }

  int get completedTodayRoutinesCount {
    final KayaDateOnly today = referenceToday;
    return todayScheduledRoutines
        .where((DailyRoutine r) => r.isCompletedOn(today))
        .length;
  }

  List<ShoppingList> get shoppingLists =>
      List<ShoppingList>.unmodifiable(_shoppingLists);

  Future<void> bindAuthenticatedUser(
    String? userId, {
    SupportedCurrency? preferredCurrency,
  }) async {
    final String? normalized = (userId?.trim().isEmpty ?? true)
        ? null
        : userId!.trim();
    if (_activeUserId == normalized &&
        _loadStatus != LifeOrganizationLoadStatus.idle) {
      if (preferredCurrency != null && preferredCurrency != _activeCurrency) {
        _activeCurrency = preferredCurrency;
        notifyListeners();
      }
      return;
    }

    _userEpoch++;
    _activeUserId = normalized;
    if (preferredCurrency != null) {
      _activeCurrency = preferredCurrency;
    }
    _clearPrivateCaches();

    if (normalized == null) {
      _loadStatus = LifeOrganizationLoadStatus.idle;
      notifyListeners();
      return;
    }

    await loadAll();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> loadAll() async {
    final String? uid = _activeUserId;
    if (uid == null) {
      _clearPrivateCaches();
      _loadStatus = LifeOrganizationLoadStatus.idle;
      notifyListeners();
      return;
    }

    final int requestEpoch = ++_userEpoch;
    _loadStatus = LifeOrganizationLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<SmartChecklist> chks = await repository.fetchChecklists(
        authenticatedUserId: uid,
      );
      final List<DailyRoutine> rtns = await repository.fetchRoutines(
        authenticatedUserId: uid,
      );
      final List<ShoppingList> shps = await repository.fetchShoppingLists(
        authenticatedUserId: uid,
      );
      if (requestEpoch != _userEpoch) {
        return;
      }
      _checklists
        ..clear()
        ..addAll(chks);
      _routines
        ..clear()
        ..addAll(rtns);
      _shoppingLists
        ..clear()
        ..addAll(shps);
      _loadStatus = LifeOrganizationLoadStatus.loaded;
    } on AuthFailure catch (failure) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage = failure.message;
      _loadStatus = LifeOrganizationLoadStatus.error;
    } catch (_) {
      if (requestEpoch != _userEpoch) {
        return;
      }
      _errorMessage =
          'Unable to load checklists, routines, and shopping lists.';
      _loadStatus = LifeOrganizationLoadStatus.error;
    }
    notifyListeners();
  }

  Future<bool> _runMutation(
    Future<void> Function(String uid) action,
    String fallbackError,
  ) async {
    final String? uid = _activeUserId;
    if (uid == null || _isMutating) {
      return false;
    }
    final int requestEpoch = _userEpoch;
    _isMutating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action(uid);
      if (requestEpoch != _userEpoch) {
        return false;
      }
      _loadStatus = LifeOrganizationLoadStatus.loaded;
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
        _errorMessage = fallbackError;
        _isMutating = false;
        notifyListeners();
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Checklists
  // ---------------------------------------------------------------------------

  Future<bool> createChecklist({required String title}) =>
      _runMutation((String uid) async {
        final SmartChecklist created = await repository.createChecklist(
          authenticatedUserId: uid,
          title: title,
        );
        _checklists.add(created);
      }, 'Failed to create checklist.');

  Future<bool> deleteChecklist(String checklistId) =>
      _runMutation((String uid) async {
        await repository.deleteChecklist(
          authenticatedUserId: uid,
          checklistId: checklistId,
        );
        _checklists.removeWhere((SmartChecklist c) => c.id == checklistId);
      }, 'Failed to delete checklist.');

  Future<bool> addChecklistItem({
    required String checklistId,
    required String title,
  }) => _runMutation((String uid) async {
    final SmartChecklist updated = await repository.addChecklistItem(
      authenticatedUserId: uid,
      checklistId: checklistId,
      title: title,
    );
    _replaceChecklist(updated);
  }, 'Failed to add checklist item.');

  Future<bool> toggleChecklistItem({
    required String checklistId,
    required String itemId,
    required bool isCompleted,
  }) => _runMutation((String uid) async {
    final SmartChecklist updated = await repository.toggleChecklistItem(
      authenticatedUserId: uid,
      checklistId: checklistId,
      itemId: itemId,
      isCompleted: isCompleted,
    );
    _replaceChecklist(updated);
  }, 'Failed to update checklist item.');

  Future<bool> resetChecklistCompletedItems(String checklistId) =>
      _runMutation((String uid) async {
        final SmartChecklist updated = await repository
            .resetChecklistCompletedItems(
              authenticatedUserId: uid,
              checklistId: checklistId,
            );
        _replaceChecklist(updated);
      }, 'Failed to reset checklist.');

  Future<bool> deleteChecklistItem({
    required String checklistId,
    required String itemId,
  }) => _runMutation((String uid) async {
    final SmartChecklist updated = await repository.deleteChecklistItem(
      authenticatedUserId: uid,
      checklistId: checklistId,
      itemId: itemId,
    );
    _replaceChecklist(updated);
  }, 'Failed to delete checklist item.');

  void _replaceChecklist(SmartChecklist updated) {
    final int idx = _checklists.indexWhere(
      (SmartChecklist c) => c.id == updated.id,
    );
    if (idx != -1) {
      _checklists[idx] = updated;
    }
  }

  // ---------------------------------------------------------------------------
  // Daily Routines
  // ---------------------------------------------------------------------------

  Future<bool> createRoutine({
    required String title,
    required Set<int> scheduledWeekdays,
    List<String> initialSteps = const <String>[],
  }) => _runMutation((String uid) async {
    final DailyRoutine created = await repository.createRoutine(
      authenticatedUserId: uid,
      title: title,
      scheduledWeekdays: scheduledWeekdays,
      initialSteps: initialSteps,
    );
    _routines.add(created);
  }, 'Failed to create routine.');

  Future<bool> deleteRoutine(String routineId) =>
      _runMutation((String uid) async {
        await repository.deleteRoutine(
          authenticatedUserId: uid,
          routineId: routineId,
        );
        _routines.removeWhere((DailyRoutine r) => r.id == routineId);
      }, 'Failed to delete routine.');

  Future<bool> addRoutineStep({
    required String routineId,
    required String title,
  }) => _runMutation((String uid) async {
    final DailyRoutine updated = await repository.addRoutineStep(
      authenticatedUserId: uid,
      routineId: routineId,
      title: title,
    );
    _replaceRoutine(updated);
  }, 'Failed to add routine step.');

  Future<bool> toggleRoutineStepToday({
    required String routineId,
    required String stepId,
    required bool isCompleted,
  }) => _runMutation((String uid) async {
    final DailyRoutine updated = await repository.toggleRoutineStepForDate(
      authenticatedUserId: uid,
      routineId: routineId,
      stepId: stepId,
      date: referenceToday,
      isCompleted: isCompleted,
    );
    _replaceRoutine(updated);
  }, 'Failed to update routine step.');

  Future<bool> deleteRoutineStep({
    required String routineId,
    required String stepId,
  }) => _runMutation((String uid) async {
    final DailyRoutine updated = await repository.deleteRoutineStep(
      authenticatedUserId: uid,
      routineId: routineId,
      stepId: stepId,
    );
    _replaceRoutine(updated);
  }, 'Failed to delete routine step.');

  void _replaceRoutine(DailyRoutine updated) {
    final int idx = _routines.indexWhere(
      (DailyRoutine r) => r.id == updated.id,
    );
    if (idx != -1) {
      _routines[idx] = updated;
    }
  }

  // ---------------------------------------------------------------------------
  // Shopping Lists
  // ---------------------------------------------------------------------------

  Future<bool> createShoppingList({required String title}) =>
      _runMutation((String uid) async {
        final ShoppingList created = await repository.createShoppingList(
          authenticatedUserId: uid,
          title: title,
          currency: _activeCurrency,
        );
        _shoppingLists.add(created);
      }, 'Failed to create shopping list.');

  Future<bool> deleteShoppingList(String shoppingListId) =>
      _runMutation((String uid) async {
        await repository.deleteShoppingList(
          authenticatedUserId: uid,
          shoppingListId: shoppingListId,
        );
        _shoppingLists.removeWhere((ShoppingList s) => s.id == shoppingListId);
      }, 'Failed to delete shopping list.');

  Future<bool> addShoppingProduct({
    required String shoppingListId,
    required String name,
    required int quantity,
    required ShoppingUnit unit,
    required int estimatedUnitPriceMinor,
  }) => _runMutation((String uid) async {
    final ShoppingList updated = await repository.addShoppingProduct(
      authenticatedUserId: uid,
      shoppingListId: shoppingListId,
      name: name,
      quantity: quantity,
      unit: unit,
      estimatedUnitPriceMinor: estimatedUnitPriceMinor,
    );
    _replaceShoppingList(updated);
  }, 'Failed to add shopping item.');

  Future<bool> toggleShoppingProductPurchased({
    required String shoppingListId,
    required String productId,
    required bool isPurchased,
  }) => _runMutation((String uid) async {
    final ShoppingList updated = await repository
        .toggleShoppingProductPurchased(
          authenticatedUserId: uid,
          shoppingListId: shoppingListId,
          productId: productId,
          isPurchased: isPurchased,
        );
    _replaceShoppingList(updated);
  }, 'Failed to update shopping item.');

  Future<bool> deleteShoppingProduct({
    required String shoppingListId,
    required String productId,
  }) => _runMutation((String uid) async {
    final ShoppingList updated = await repository.deleteShoppingProduct(
      authenticatedUserId: uid,
      shoppingListId: shoppingListId,
      productId: productId,
    );
    _replaceShoppingList(updated);
  }, 'Failed to delete shopping item.');

  void _replaceShoppingList(ShoppingList updated) {
    final int idx = _shoppingLists.indexWhere(
      (ShoppingList s) => s.id == updated.id,
    );
    if (idx != -1) {
      _shoppingLists[idx] = updated;
    }
  }

  void _clearPrivateCaches() {
    _checklists.clear();
    _routines.clear();
    _shoppingLists.clear();
    _errorMessage = null;
    _isMutating = false;
  }
}
