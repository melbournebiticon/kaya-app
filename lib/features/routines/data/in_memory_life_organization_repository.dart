import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/life_organization_validators.dart';
import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/checklists/domain/smart_checklist.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/routines/domain/life_organization_repository.dart';
import 'package:kaya/features/shopping/domain/shopping_list.dart';

/// Deterministic, RLS-enforcing implementation of [LifeOrganizationRepository].
class InMemoryLifeOrganizationRepository implements LifeOrganizationRepository {
  InMemoryLifeOrganizationRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, SmartChecklist> _checklistsById =
      <String, SmartChecklist>{};
  final Map<String, DailyRoutine> _routinesById = <String, DailyRoutine>{};
  final Map<String, ShoppingList> _shoppingListsById = <String, ShoppingList>{};

  int _seq = 1;
  bool simulateNetworkFailure = false;

  void _checkNetwork() {
    if (simulateNetworkFailure) {
      throw AuthFailure.network(
        'Unable to synchronize Life Organization records. Please check your connection.',
      );
    }
  }

  String _requireAuthenticatedUser(String authenticatedUserId) {
    final String trimmed = authenticatedUserId.trim();
    if (trimmed.isEmpty) {
      throw AuthFailure.unauthorizedAccess();
    }
    return trimmed;
  }

  SmartChecklist _requireOwnedChecklist(String uid, String checklistId) {
    final SmartChecklist? existing = _checklistsById[checklistId.trim()];
    if (existing == null || existing.userId != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return existing;
  }

  DailyRoutine _requireOwnedRoutine(String uid, String routineId) {
    final DailyRoutine? existing = _routinesById[routineId.trim()];
    if (existing == null || existing.userId != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return existing;
  }

  ShoppingList _requireOwnedShoppingList(String uid, String listId) {
    final ShoppingList? existing = _shoppingListsById[listId.trim()];
    if (existing == null || existing.userId != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return existing;
  }

  void _validateTitle(String raw, String fieldName) {
    final String? err = LifeOrganizationValidators.validateTitle(
      raw,
      fieldName: fieldName,
    );
    if (err != null) {
      throw AuthFailure.validation(err);
    }
  }

  // ---------------------------------------------------------------------------
  // Smart Checklists
  // ---------------------------------------------------------------------------

  @override
  Future<List<SmartChecklist>> fetchChecklists({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return _checklistsById.values
        .where((SmartChecklist c) => c.userId == uid)
        .toList();
  }

  @override
  Future<SmartChecklist> createChecklist({
    required String authenticatedUserId,
    required String title,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    _validateTitle(title, 'Checklist title');

    final DateTime now = _clock().toUtc();
    final String id = 'chk_${_seq++}';
    final SmartChecklist created = SmartChecklist(
      id: id,
      userId: uid,
      title: title.trim(),
      items: const <ChecklistItemEntry>[],
      createdAt: now,
      updatedAt: now,
    );
    _checklistsById[id] = created;
    return created;
  }

  @override
  Future<void> deleteChecklist({
    required String authenticatedUserId,
    required String checklistId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final SmartChecklist existing = _requireOwnedChecklist(uid, checklistId);
    _checklistsById.remove(existing.id);
  }

  @override
  Future<SmartChecklist> addChecklistItem({
    required String authenticatedUserId,
    required String checklistId,
    required String title,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final SmartChecklist existing = _requireOwnedChecklist(uid, checklistId);
    _validateTitle(title, 'Checklist item');

    final ChecklistItemEntry entry = ChecklistItemEntry(
      id: 'chi_${_seq++}',
      title: title.trim(),
      isCompleted: false,
    );
    final SmartChecklist updated = existing.copyWith(
      items: <ChecklistItemEntry>[...existing.items, entry],
      updatedAt: _clock().toUtc(),
    );
    _checklistsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<SmartChecklist> toggleChecklistItem({
    required String authenticatedUserId,
    required String checklistId,
    required String itemId,
    required bool isCompleted,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final SmartChecklist existing = _requireOwnedChecklist(uid, checklistId);

    final List<ChecklistItemEntry> nextItems = existing.items
        .map(
          (ChecklistItemEntry item) => item.id == itemId
              ? item.copyWith(isCompleted: isCompleted)
              : item,
        )
        .toList(growable: false);
    final SmartChecklist updated = existing.copyWith(
      items: nextItems,
      updatedAt: _clock().toUtc(),
    );
    _checklistsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<SmartChecklist> resetChecklistCompletedItems({
    required String authenticatedUserId,
    required String checklistId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final SmartChecklist existing = _requireOwnedChecklist(uid, checklistId);

    final List<ChecklistItemEntry> resetItems = existing.items
        .map((ChecklistItemEntry item) => item.copyWith(isCompleted: false))
        .toList(growable: false);
    final SmartChecklist updated = existing.copyWith(
      items: resetItems,
      updatedAt: _clock().toUtc(),
    );
    _checklistsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<SmartChecklist> deleteChecklistItem({
    required String authenticatedUserId,
    required String checklistId,
    required String itemId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final SmartChecklist existing = _requireOwnedChecklist(uid, checklistId);

    final List<ChecklistItemEntry> nextItems = existing.items
        .where((ChecklistItemEntry item) => item.id != itemId)
        .toList(growable: false);
    final SmartChecklist updated = existing.copyWith(
      items: nextItems,
      updatedAt: _clock().toUtc(),
    );
    _checklistsById[existing.id] = updated;
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Daily Routines
  // ---------------------------------------------------------------------------

  @override
  Future<List<DailyRoutine>> fetchRoutines({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return _routinesById.values
        .where((DailyRoutine r) => r.userId == uid)
        .toList();
  }

  @override
  Future<DailyRoutine> createRoutine({
    required String authenticatedUserId,
    required String title,
    required Set<int> scheduledWeekdays,
    List<String> initialSteps = const <String>[],
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    _validateTitle(title, 'Routine name');
    final String? daysError =
        LifeOrganizationValidators.validateScheduledWeekdays(scheduledWeekdays);
    if (daysError != null) {
      throw AuthFailure.validation(daysError);
    }

    final List<RoutineStep> steps = <RoutineStep>[];
    for (final String rawStep in initialSteps) {
      final String trimmed = rawStep.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      _validateTitle(trimmed, 'Routine step');
      steps.add(RoutineStep(id: 'rst_${_seq++}', title: trimmed));
    }

    final DateTime now = _clock().toUtc();
    final String id = 'rtn_${_seq++}';
    final DailyRoutine created = DailyRoutine(
      id: id,
      userId: uid,
      title: title.trim(),
      scheduledWeekdays: Set<int>.unmodifiable(scheduledWeekdays),
      steps: List<RoutineStep>.unmodifiable(steps),
      completedStepIdsByDateKey: const <String, Set<String>>{},
      createdAt: now,
      updatedAt: now,
    );
    _routinesById[id] = created;
    return created;
  }

  @override
  Future<void> deleteRoutine({
    required String authenticatedUserId,
    required String routineId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final DailyRoutine existing = _requireOwnedRoutine(uid, routineId);
    _routinesById.remove(existing.id);
  }

  @override
  Future<DailyRoutine> addRoutineStep({
    required String authenticatedUserId,
    required String routineId,
    required String title,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final DailyRoutine existing = _requireOwnedRoutine(uid, routineId);
    _validateTitle(title, 'Routine step');

    final RoutineStep step = RoutineStep(
      id: 'rst_${_seq++}',
      title: title.trim(),
    );
    final DailyRoutine updated = existing.copyWith(
      steps: <RoutineStep>[...existing.steps, step],
      updatedAt: _clock().toUtc(),
    );
    _routinesById[existing.id] = updated;
    return updated;
  }

  @override
  Future<DailyRoutine> toggleRoutineStepForDate({
    required String authenticatedUserId,
    required String routineId,
    required String stepId,
    required KayaDateOnly date,
    required bool isCompleted,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final DailyRoutine existing = _requireOwnedRoutine(uid, routineId);
    if (!existing.steps.any((RoutineStep s) => s.id == stepId)) {
      throw AuthFailure.validation('Routine step not found.');
    }

    final String dateKey = date.toIsoDateString();
    final Map<String, Set<String>> nextMap = <String, Set<String>>{
      for (final MapEntry<String, Set<String>> e
          in existing.completedStepIdsByDateKey.entries)
        e.key: Set<String>.from(e.value),
    };
    final Set<String> daySet = nextMap.putIfAbsent(dateKey, () => <String>{});
    if (isCompleted) {
      daySet.add(stepId);
    } else {
      daySet.remove(stepId);
    }

    final DailyRoutine updated = existing.copyWith(
      completedStepIdsByDateKey: nextMap,
      updatedAt: _clock().toUtc(),
    );
    _routinesById[existing.id] = updated;
    return updated;
  }

  @override
  Future<DailyRoutine> deleteRoutineStep({
    required String authenticatedUserId,
    required String routineId,
    required String stepId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final DailyRoutine existing = _requireOwnedRoutine(uid, routineId);

    final List<RoutineStep> nextSteps = existing.steps
        .where((RoutineStep s) => s.id != stepId)
        .toList(growable: false);
    final Map<String, Set<String>> nextMap = <String, Set<String>>{
      for (final MapEntry<String, Set<String>> e
          in existing.completedStepIdsByDateKey.entries)
        e.key: Set<String>.from(e.value)..remove(stepId),
    };

    final DailyRoutine updated = existing.copyWith(
      steps: nextSteps,
      completedStepIdsByDateKey: nextMap,
      updatedAt: _clock().toUtc(),
    );
    _routinesById[existing.id] = updated;
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Shopping Lists (Strictly Estimates — Never Recorded as Expenses)
  // ---------------------------------------------------------------------------

  @override
  Future<List<ShoppingList>> fetchShoppingLists({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return _shoppingListsById.values
        .where((ShoppingList s) => s.userId == uid)
        .toList();
  }

  @override
  Future<ShoppingList> createShoppingList({
    required String authenticatedUserId,
    required String title,
    required SupportedCurrency currency,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    _validateTitle(title, 'Shopping list name');

    final DateTime now = _clock().toUtc();
    final String id = 'shp_${_seq++}';
    final ShoppingList created = ShoppingList(
      id: id,
      userId: uid,
      title: title.trim(),
      currency: currency,
      items: const <ShoppingProductItem>[],
      createdAt: now,
      updatedAt: now,
    );
    _shoppingListsById[id] = created;
    return created;
  }

  @override
  Future<void> deleteShoppingList({
    required String authenticatedUserId,
    required String shoppingListId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final ShoppingList existing = _requireOwnedShoppingList(
      uid,
      shoppingListId,
    );
    _shoppingListsById.remove(existing.id);
  }

  @override
  Future<ShoppingList> addShoppingProduct({
    required String authenticatedUserId,
    required String shoppingListId,
    required String name,
    required int quantity,
    required ShoppingUnit unit,
    required int estimatedUnitPriceMinor,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final ShoppingList existing = _requireOwnedShoppingList(
      uid,
      shoppingListId,
    );
    _validateTitle(name, 'Product name');

    final String? qtyErr = LifeOrganizationValidators.validateQuantity(
      quantity,
    );
    if (qtyErr != null) {
      throw AuthFailure.validation(qtyErr);
    }
    if (estimatedUnitPriceMinor < 0 ||
        estimatedUnitPriceMinor > MoneyValidators.maxAmountMinor) {
      throw AuthFailure.validation('Estimated unit price is out of range.');
    }

    final ShoppingProductItem item = ShoppingProductItem(
      id: 'shi_${_seq++}',
      name: name.trim(),
      quantity: quantity,
      unit: unit,
      estimatedUnitPriceMinor: estimatedUnitPriceMinor,
      isPurchased: false,
    );
    final ShoppingList updated = existing.copyWith(
      items: <ShoppingProductItem>[...existing.items, item],
      updatedAt: _clock().toUtc(),
    );
    _shoppingListsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<ShoppingList> toggleShoppingProductPurchased({
    required String authenticatedUserId,
    required String shoppingListId,
    required String productId,
    required bool isPurchased,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final ShoppingList existing = _requireOwnedShoppingList(
      uid,
      shoppingListId,
    );

    final List<ShoppingProductItem> nextItems = existing.items
        .map(
          (ShoppingProductItem item) => item.id == productId
              ? item.copyWith(isPurchased: isPurchased)
              : item,
        )
        .toList(growable: false);
    final ShoppingList updated = existing.copyWith(
      items: nextItems,
      updatedAt: _clock().toUtc(),
    );
    _shoppingListsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<ShoppingList> deleteShoppingProduct({
    required String authenticatedUserId,
    required String shoppingListId,
    required String productId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final ShoppingList existing = _requireOwnedShoppingList(
      uid,
      shoppingListId,
    );

    final List<ShoppingProductItem> nextItems = existing.items
        .where((ShoppingProductItem item) => item.id != productId)
        .toList(growable: false);
    final ShoppingList updated = existing.copyWith(
      items: nextItems,
      updatedAt: _clock().toUtc(),
    );
    _shoppingListsById[existing.id] = updated;
    return updated;
  }
}
