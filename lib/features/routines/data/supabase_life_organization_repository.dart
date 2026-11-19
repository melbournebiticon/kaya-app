import 'package:kaya/core/data/supabase_error_mapper.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/life_organization_validators.dart';
import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/checklists/domain/smart_checklist.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/routines/domain/life_organization_repository.dart';
import 'package:kaya/features/shopping/domain/shopping_list.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live Supabase implementation of [LifeOrganizationRepository] (Phase 7).
class SupabaseLifeOrganizationRepository implements LifeOrganizationRepository {
  SupabaseLifeOrganizationRepository({required this.client});

  final SupabaseClient client;

  Future<SmartChecklist> _fetchChecklistById({
    required String uid,
    required String checklistId,
  }) async {
    final Map<String, dynamic> row = await client
        .from('checklists')
        .select()
        .eq('id', checklistId)
        .eq('user_id', uid)
        .single();
    final List<dynamic> itemRows = await client
        .from('checklist_items')
        .select()
        .eq('checklist_id', checklistId)
        .eq('user_id', uid)
        .order('position', ascending: true)
        .order('created_at', ascending: true);
    return _checklistFromRows(row, itemRows);
  }

  SmartChecklist _checklistFromRows(
    Map<String, dynamic> row,
    List<dynamic> itemRows,
  ) {
    final List<ChecklistItemEntry> items = itemRows
        .map((dynamic r) {
          final Map<String, dynamic> m = Map<String, dynamic>.from(r as Map);
          return ChecklistItemEntry(
            id: (m['id'] as String).trim(),
            title: (m['title'] as String? ?? '').trim(),
            isCompleted: m['is_completed'] as bool? ?? false,
          );
        })
        .toList(growable: false);
    return SmartChecklist(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      title: (row['title'] as String? ?? '').trim(),
      items: items,
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  Future<DailyRoutine> _fetchRoutineById({
    required String uid,
    required String routineId,
  }) async {
    final Map<String, dynamic> row = await client
        .from('daily_routines')
        .select()
        .eq('id', routineId)
        .eq('user_id', uid)
        .single();
    final List<dynamic> stepRows = await client
        .from('routine_steps')
        .select()
        .eq('routine_id', routineId)
        .eq('user_id', uid)
        .order('position', ascending: true)
        .order('created_at', ascending: true);
    final List<dynamic> completionRows = await client
        .from('routine_step_completions')
        .select()
        .eq('routine_id', routineId)
        .eq('user_id', uid);
    return _routineFromRows(row, stepRows, completionRows);
  }

  DailyRoutine _routineFromRows(
    Map<String, dynamic> row,
    List<dynamic> stepRows,
    List<dynamic> completionRows,
  ) {
    final List<RoutineStep> steps = stepRows
        .map((dynamic r) {
          final Map<String, dynamic> m = Map<String, dynamic>.from(r as Map);
          return RoutineStep(
            id: (m['id'] as String).trim(),
            title: (m['title'] as String? ?? '').trim(),
          );
        })
        .toList(growable: false);

    final Map<String, Set<String>> completionsByDate = <String, Set<String>>{};
    for (final dynamic r in completionRows) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(r as Map);
      final KayaDateOnly? date = SupabaseErrorMapper.parseOptionalDateOnly(
        m['completion_date'],
      );
      final String stepId = (m['step_id'] as String? ?? '').trim();
      if (date != null && stepId.isNotEmpty) {
        completionsByDate
            .putIfAbsent(date.toIsoDateString(), () => <String>{})
            .add(stepId);
      }
    }

    final List<dynamic> rawWeekdays =
        row['scheduled_weekdays'] as List<dynamic>? ?? <dynamic>[];
    final Set<int> weekdays = rawWeekdays
        .map((dynamic d) => SupabaseErrorMapper.parseInt(d))
        .where((int d) => d >= 1 && d <= 7)
        .toSet();

    return DailyRoutine(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      title: (row['title'] as String? ?? '').trim(),
      scheduledWeekdays: Set<int>.unmodifiable(weekdays),
      steps: steps,
      completedStepIdsByDateKey: completionsByDate,
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  Future<ShoppingList> _fetchShoppingListById({
    required String uid,
    required String shoppingListId,
  }) async {
    final Map<String, dynamic> row = await client
        .from('shopping_lists')
        .select()
        .eq('id', shoppingListId)
        .eq('user_id', uid)
        .single();
    final List<dynamic> itemRows = await client
        .from('shopping_list_items')
        .select()
        .eq('shopping_list_id', shoppingListId)
        .eq('user_id', uid)
        .order('created_at', ascending: true);
    return _shoppingListFromRows(row, itemRows);
  }

  ShoppingList _shoppingListFromRows(
    Map<String, dynamic> row,
    List<dynamic> itemRows,
  ) {
    final List<ShoppingProductItem> items = itemRows
        .map((dynamic r) {
          final Map<String, dynamic> m = Map<String, dynamic>.from(r as Map);
          return ShoppingProductItem(
            id: (m['id'] as String).trim(),
            name: (m['name'] as String? ?? '').trim(),
            quantity: SupabaseErrorMapper.parseInt(m['quantity'], fallback: 1),
            unit:
                ShoppingUnit.tryFromDbValue(m['unit'] as String?) ??
                ShoppingUnit.pcs,
            estimatedUnitPriceMinor: SupabaseErrorMapper.parseInt(
              m['estimated_unit_price_minor'],
            ),
            isPurchased: m['is_purchased'] as bool? ?? false,
          );
        })
        .toList(growable: false);

    return ShoppingList(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      title: (row['title'] as String? ?? '').trim(),
      currency:
          SupportedCurrency.tryFromCode(row['currency'] as String?) ??
          SupportedCurrency.php,
      items: items,
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  // ---------------------------------------------------------------------------
  // Smart Checklists
  // ---------------------------------------------------------------------------

  @override
  Future<List<SmartChecklist>> fetchChecklists({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
      requestedOwnerId: requestedOwnerId,
    );
    try {
      final List<dynamic> listRows = await client
          .from('checklists')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      final List<dynamic> itemRows = await client
          .from('checklist_items')
          .select()
          .eq('user_id', uid)
          .order('position', ascending: true)
          .order('created_at', ascending: true);

      final Map<String, List<dynamic>> itemsByChecklist =
          <String, List<dynamic>>{};
      for (final dynamic item in itemRows) {
        final String parentId = ((item as Map)['checklist_id'] as String? ?? '')
            .trim();
        itemsByChecklist.putIfAbsent(parentId, () => <dynamic>[]).add(item);
      }

      return listRows
          .map((dynamic row) {
            final Map<String, dynamic> m = Map<String, dynamic>.from(
              row as Map,
            );
            final String id = (m['id'] as String).trim();
            return _checklistFromRows(m, itemsByChecklist[id] ?? <dynamic>[]);
          })
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Unable to load checklists.');
    }
  }

  @override
  Future<SmartChecklist> createChecklist({
    required String authenticatedUserId,
    required String title,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    final String? err = LifeOrganizationValidators.validateTitle(
      title,
      fieldName: 'Checklist name',
    );
    if (err != null) {
      throw AuthFailure.validation(err);
    }
    try {
      final Map<String, dynamic> row = await client
          .from('checklists')
          .insert(<String, dynamic>{'user_id': uid, 'title': title.trim()})
          .select()
          .single();
      return _checklistFromRows(row, const <dynamic>[]);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to create checklist.');
    }
  }

  @override
  Future<void> deleteChecklist({
    required String authenticatedUserId,
    required String checklistId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('checklists')
          .delete()
          .eq('id', checklistId)
          .eq('user_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to delete checklist.');
    }
  }

  @override
  Future<SmartChecklist> addChecklistItem({
    required String authenticatedUserId,
    required String checklistId,
    required String title,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    final String? err = LifeOrganizationValidators.validateTitle(
      title,
      fieldName: 'Item name',
    );
    if (err != null) {
      throw AuthFailure.validation(err);
    }
    try {
      final List<dynamic> existing = await client
          .from('checklist_items')
          .select('id')
          .eq('checklist_id', checklistId)
          .eq('user_id', uid);
      await client.from('checklist_items').insert(<String, dynamic>{
        'user_id': uid,
        'checklist_id': checklistId,
        'title': title.trim(),
        'position': existing.length,
      });
      return await _fetchChecklistById(uid: uid, checklistId: checklistId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to add checklist item.');
    }
  }

  @override
  Future<SmartChecklist> toggleChecklistItem({
    required String authenticatedUserId,
    required String checklistId,
    required String itemId,
    required bool isCompleted,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('checklist_items')
          .update(<String, dynamic>{'is_completed': isCompleted})
          .eq('id', itemId)
          .eq('checklist_id', checklistId)
          .eq('user_id', uid);
      return await _fetchChecklistById(uid: uid, checklistId: checklistId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update checklist item.');
    }
  }

  @override
  Future<SmartChecklist> resetChecklistCompletedItems({
    required String authenticatedUserId,
    required String checklistId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('checklist_items')
          .update(<String, dynamic>{'is_completed': false})
          .eq('checklist_id', checklistId)
          .eq('user_id', uid);
      return await _fetchChecklistById(uid: uid, checklistId: checklistId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to reset checklist.');
    }
  }

  @override
  Future<SmartChecklist> deleteChecklistItem({
    required String authenticatedUserId,
    required String checklistId,
    required String itemId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('checklist_items')
          .delete()
          .eq('id', itemId)
          .eq('checklist_id', checklistId)
          .eq('user_id', uid);
      return await _fetchChecklistById(uid: uid, checklistId: checklistId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to remove checklist item.');
    }
  }

  // ---------------------------------------------------------------------------
  // Daily Routines
  // ---------------------------------------------------------------------------

  @override
  Future<List<DailyRoutine>> fetchRoutines({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
      requestedOwnerId: requestedOwnerId,
    );
    try {
      final List<dynamic> routineRows = await client
          .from('daily_routines')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      final List<dynamic> stepRows = await client
          .from('routine_steps')
          .select()
          .eq('user_id', uid)
          .order('position', ascending: true)
          .order('created_at', ascending: true);
      final List<dynamic> completionRows = await client
          .from('routine_step_completions')
          .select()
          .eq('user_id', uid);

      final Map<String, List<dynamic>> stepsByRoutine =
          <String, List<dynamic>>{};
      for (final dynamic s in stepRows) {
        final String rid = ((s as Map)['routine_id'] as String? ?? '').trim();
        stepsByRoutine.putIfAbsent(rid, () => <dynamic>[]).add(s);
      }

      final Map<String, List<dynamic>> completionsByRoutine =
          <String, List<dynamic>>{};
      for (final dynamic c in completionRows) {
        final String rid = ((c as Map)['routine_id'] as String? ?? '').trim();
        completionsByRoutine.putIfAbsent(rid, () => <dynamic>[]).add(c);
      }

      return routineRows
          .map((dynamic row) {
            final Map<String, dynamic> m = Map<String, dynamic>.from(
              row as Map,
            );
            final String id = (m['id'] as String).trim();
            return _routineFromRows(
              m,
              stepsByRoutine[id] ?? <dynamic>[],
              completionsByRoutine[id] ?? <dynamic>[],
            );
          })
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Unable to load daily routines.');
    }
  }

  @override
  Future<DailyRoutine> createRoutine({
    required String authenticatedUserId,
    required String title,
    required Set<int> scheduledWeekdays,
    List<String> initialSteps = const <String>[],
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    final String? titleErr = LifeOrganizationValidators.validateTitle(
      title,
      fieldName: 'Routine name',
    );
    if (titleErr != null) {
      throw AuthFailure.validation(titleErr);
    }
    final String? daysErr =
        LifeOrganizationValidators.validateScheduledWeekdays(scheduledWeekdays);
    if (daysErr != null) {
      throw AuthFailure.validation(daysErr);
    }

    final List<String> cleanSteps = <String>[];
    for (final String raw in initialSteps) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final String? stepErr = LifeOrganizationValidators.validateTitle(
        trimmed,
        fieldName: 'Routine step',
      );
      if (stepErr != null) {
        throw AuthFailure.validation(stepErr);
      }
      cleanSteps.add(trimmed);
    }

    final List<int> sortedDays = scheduledWeekdays.toList()..sort();
    try {
      final Map<String, dynamic> routineRow = await client
          .from('daily_routines')
          .insert(<String, dynamic>{
            'user_id': uid,
            'title': title.trim(),
            'scheduled_weekdays': sortedDays,
          })
          .select()
          .single();
      final String routineId = (routineRow['id'] as String).trim();

      if (cleanSteps.isNotEmpty) {
        await client.from('routine_steps').insert(<Map<String, dynamic>>[
          for (int i = 0; i < cleanSteps.length; i++)
            <String, dynamic>{
              'user_id': uid,
              'routine_id': routineId,
              'title': cleanSteps[i],
              'position': i,
            },
        ]);
      }

      return await _fetchRoutineById(uid: uid, routineId: routineId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to create routine.');
    }
  }

  @override
  Future<void> deleteRoutine({
    required String authenticatedUserId,
    required String routineId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('daily_routines')
          .delete()
          .eq('id', routineId)
          .eq('user_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to delete routine.');
    }
  }

  @override
  Future<DailyRoutine> addRoutineStep({
    required String authenticatedUserId,
    required String routineId,
    required String title,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    final String? err = LifeOrganizationValidators.validateTitle(
      title,
      fieldName: 'Routine step',
    );
    if (err != null) {
      throw AuthFailure.validation(err);
    }
    try {
      final List<dynamic> existing = await client
          .from('routine_steps')
          .select('id')
          .eq('routine_id', routineId)
          .eq('user_id', uid);
      await client.from('routine_steps').insert(<String, dynamic>{
        'user_id': uid,
        'routine_id': routineId,
        'title': title.trim(),
        'position': existing.length,
      });
      return await _fetchRoutineById(uid: uid, routineId: routineId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to add routine step.');
    }
  }

  @override
  Future<DailyRoutine> toggleRoutineStepForDate({
    required String authenticatedUserId,
    required String routineId,
    required String stepId,
    required KayaDateOnly date,
    required bool isCompleted,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    final String dateStr = date.toIsoDateString();
    try {
      if (isCompleted) {
        await client.from('routine_step_completions').upsert(<String, dynamic>{
          'user_id': uid,
          'routine_id': routineId,
          'step_id': stepId,
          'completion_date': dateStr,
        }, onConflict: 'user_id,step_id,completion_date');
      } else {
        await client
            .from('routine_step_completions')
            .delete()
            .eq('user_id', uid)
            .eq('routine_id', routineId)
            .eq('step_id', stepId)
            .eq('completion_date', dateStr);
      }
      return await _fetchRoutineById(uid: uid, routineId: routineId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update routine progress.');
    }
  }

  @override
  Future<DailyRoutine> deleteRoutineStep({
    required String authenticatedUserId,
    required String routineId,
    required String stepId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('routine_steps')
          .delete()
          .eq('id', stepId)
          .eq('routine_id', routineId)
          .eq('user_id', uid);
      return await _fetchRoutineById(uid: uid, routineId: routineId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to delete routine step.');
    }
  }

  // ---------------------------------------------------------------------------
  // Shopping Lists
  // ---------------------------------------------------------------------------

  @override
  Future<List<ShoppingList>> fetchShoppingLists({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
      requestedOwnerId: requestedOwnerId,
    );
    try {
      final List<dynamic> listRows = await client
          .from('shopping_lists')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      final List<dynamic> itemRows = await client
          .from('shopping_list_items')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      final Map<String, List<dynamic>> itemsByList = <String, List<dynamic>>{};
      for (final dynamic item in itemRows) {
        final String lid = ((item as Map)['shopping_list_id'] as String? ?? '')
            .trim();
        itemsByList.putIfAbsent(lid, () => <dynamic>[]).add(item);
      }

      return listRows
          .map((dynamic row) {
            final Map<String, dynamic> m = Map<String, dynamic>.from(
              row as Map,
            );
            final String id = (m['id'] as String).trim();
            return _shoppingListFromRows(m, itemsByList[id] ?? <dynamic>[]);
          })
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Unable to load shopping lists.');
    }
  }

  @override
  Future<ShoppingList> createShoppingList({
    required String authenticatedUserId,
    required String title,
    required SupportedCurrency currency,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    final String? err = LifeOrganizationValidators.validateTitle(
      title,
      fieldName: 'Shopping list name',
    );
    if (err != null) {
      throw AuthFailure.validation(err);
    }
    try {
      final Map<String, dynamic> row = await client
          .from('shopping_lists')
          .insert(<String, dynamic>{
            'user_id': uid,
            'title': title.trim(),
            'currency': currency.code,
          })
          .select()
          .single();
      return _shoppingListFromRows(row, const <dynamic>[]);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to create shopping list.');
    }
  }

  @override
  Future<void> deleteShoppingList({
    required String authenticatedUserId,
    required String shoppingListId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('shopping_lists')
          .delete()
          .eq('id', shoppingListId)
          .eq('user_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to delete shopping list.');
    }
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
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    final String? nameErr = LifeOrganizationValidators.validateTitle(
      name,
      fieldName: 'Product name',
    );
    if (nameErr != null) {
      throw AuthFailure.validation(nameErr);
    }
    final String? qtyErr = LifeOrganizationValidators.validateQuantity(
      quantity,
    );
    if (qtyErr != null) {
      throw AuthFailure.validation(qtyErr);
    }
    if (estimatedUnitPriceMinor < 0 ||
        estimatedUnitPriceMinor > MoneyValidators.maxAmountMinor) {
      throw AuthFailure.validation(
        'Estimated unit price is out of supported range.',
      );
    }
    try {
      await client.from('shopping_list_items').insert(<String, dynamic>{
        'user_id': uid,
        'shopping_list_id': shoppingListId,
        'name': name.trim(),
        'quantity': quantity,
        'unit': unit.dbValue,
        'estimated_unit_price_minor': estimatedUnitPriceMinor,
      });
      return await _fetchShoppingListById(
        uid: uid,
        shoppingListId: shoppingListId,
      );
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to add shopping item.');
    }
  }

  @override
  Future<ShoppingList> toggleShoppingProductPurchased({
    required String authenticatedUserId,
    required String shoppingListId,
    required String productId,
    required bool isPurchased,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('shopping_list_items')
          .update(<String, dynamic>{'is_purchased': isPurchased})
          .eq('id', productId)
          .eq('shopping_list_id', shoppingListId)
          .eq('user_id', uid);
      return await _fetchShoppingListById(
        uid: uid,
        shoppingListId: shoppingListId,
      );
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update shopping item.');
    }
  }

  @override
  Future<ShoppingList> deleteShoppingProduct({
    required String authenticatedUserId,
    required String shoppingListId,
    required String productId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('shopping_list_items')
          .delete()
          .eq('id', productId)
          .eq('shopping_list_id', shoppingListId)
          .eq('user_id', uid);
      return await _fetchShoppingListById(
        uid: uid,
        shoppingListId: shoppingListId,
      );
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to remove shopping item.');
    }
  }
}
