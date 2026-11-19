import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/checklists/domain/smart_checklist.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/shopping/domain/shopping_list.dart';

/// Repository contract for Phase 7 Life Organization: Smart Checklists,
/// Daily Routines, and Shopping Lists.
abstract class LifeOrganizationRepository {
  // Checklists
  Future<List<SmartChecklist>> fetchChecklists({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  Future<SmartChecklist> createChecklist({
    required String authenticatedUserId,
    required String title,
  });

  Future<void> deleteChecklist({
    required String authenticatedUserId,
    required String checklistId,
  });

  Future<SmartChecklist> addChecklistItem({
    required String authenticatedUserId,
    required String checklistId,
    required String title,
  });

  Future<SmartChecklist> toggleChecklistItem({
    required String authenticatedUserId,
    required String checklistId,
    required String itemId,
    required bool isCompleted,
  });

  Future<SmartChecklist> resetChecklistCompletedItems({
    required String authenticatedUserId,
    required String checklistId,
  });

  Future<SmartChecklist> deleteChecklistItem({
    required String authenticatedUserId,
    required String checklistId,
    required String itemId,
  });

  // Daily Routines
  Future<List<DailyRoutine>> fetchRoutines({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  Future<DailyRoutine> createRoutine({
    required String authenticatedUserId,
    required String title,
    required Set<int> scheduledWeekdays,
    List<String> initialSteps = const <String>[],
  });

  Future<void> deleteRoutine({
    required String authenticatedUserId,
    required String routineId,
  });

  Future<DailyRoutine> addRoutineStep({
    required String authenticatedUserId,
    required String routineId,
    required String title,
  });

  Future<DailyRoutine> toggleRoutineStepForDate({
    required String authenticatedUserId,
    required String routineId,
    required String stepId,
    required KayaDateOnly date,
    required bool isCompleted,
  });

  Future<DailyRoutine> deleteRoutineStep({
    required String authenticatedUserId,
    required String routineId,
    required String stepId,
  });

  // Shopping Lists
  Future<List<ShoppingList>> fetchShoppingLists({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  Future<ShoppingList> createShoppingList({
    required String authenticatedUserId,
    required String title,
    required SupportedCurrency currency,
  });

  Future<void> deleteShoppingList({
    required String authenticatedUserId,
    required String shoppingListId,
  });

  Future<ShoppingList> addShoppingProduct({
    required String authenticatedUserId,
    required String shoppingListId,
    required String name,
    required int quantity,
    required ShoppingUnit unit,
    required int estimatedUnitPriceMinor,
  });

  Future<ShoppingList> toggleShoppingProductPurchased({
    required String authenticatedUserId,
    required String shoppingListId,
    required String productId,
    required bool isPurchased,
  });

  Future<ShoppingList> deleteShoppingProduct({
    required String authenticatedUserId,
    required String shoppingListId,
    required String productId,
  });
}
