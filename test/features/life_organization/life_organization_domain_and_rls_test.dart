import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/life_organization_validators.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/checklists/domain/smart_checklist.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/data/in_memory_life_organization_repository.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/shopping/domain/shopping_list.dart';

void main() {
  group('DailyRoutine Scheduling, Progress & Multi-Day Streak Accuracy', () {
    test(
      'counts consecutive scheduled days while skipping unscheduled rest days',
      () {
        final DateTime nowUtc = DateTime.utc(2026, 11, 16, 9, 0);
        // Nov 16, 2026 is Monday (1). Schedule Mon (1), Wed (3), Fri (5).
        const KayaDateOnly monNov16 = KayaDateOnly(2026, 11, 16);
        const KayaDateOnly friNov13 = KayaDateOnly(2026, 11, 13);
        const KayaDateOnly wedNov11 = KayaDateOnly(2026, 11, 11);

        expect(monNov16.weekday, DateTime.monday);
        expect(friNov13.weekday, DateTime.friday);

        final DailyRoutine openTodayStreak = DailyRoutine(
          id: 'rtn_1',
          userId: 'usr_a',
          title: 'Workout',
          scheduledWeekdays: const <int>{1, 3, 5},
          steps: const <RoutineStep>[
            RoutineStep(id: 's1', title: 'Warmup'),
            RoutineStep(id: 's2', title: 'Core'),
          ],
          completedStepIdsByDateKey: <String, Set<String>>{
            wedNov11.toIsoDateString(): <String>{'s1', 's2'},
            friNov13.toIsoDateString(): <String>{'s1', 's2'},
          },
          createdAt: nowUtc,
          updatedAt: nowUtc,
        );

        // Today (Mon Nov 16) is still in progress -> streak from Wed + Fri = 2.
        expect(openTodayStreak.isScheduledOn(monNov16), isTrue);
        expect(openTodayStreak.currentStreak(monNov16), 2);

        // Completing today increments streak across weekend rest days to 3.
        final DailyRoutine completedToday = openTodayStreak.copyWith(
          completedStepIdsByDateKey: <String, Set<String>>{
            ...openTodayStreak.completedStepIdsByDateKey,
            monNov16.toIsoDateString(): <String>{'s1', 's2'},
          },
        );
        expect(completedToday.isCompletedOn(monNov16), isTrue);
        expect(completedToday.currentStreak(monNov16), 3);

        // Missing Friday breaks the streak from Wednesday -> only Monday counts (1).
        final DailyRoutine missedFriday = completedToday.copyWith(
          completedStepIdsByDateKey: <String, Set<String>>{
            wedNov11.toIsoDateString(): <String>{'s1', 's2'},
            monNov16.toIsoDateString(): <String>{'s1', 's2'},
          },
        );
        expect(missedFriday.currentStreak(monNov16), 1);
      },
    );
  });

  group('ShoppingList Calculations & Expense Isolation', () {
    test(
      'computes estimated and remaining totals without altering Money expenses',
      () async {
        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 10, 0);
        final InMemoryMoneyRepository moneyRepo = InMemoryMoneyRepository(
          clock: () => fixedNow,
        );
        final MoneyController moneyCtrl = MoneyController(
          repository: moneyRepo,
          clock: () => fixedNow,
          initialUserId: 'usr_a',
          initialCurrency: SupportedCurrency.php,
        );
        await moneyCtrl.loadMoneyData();

        final InMemoryLifeOrganizationRepository orgRepo =
            InMemoryLifeOrganizationRepository(clock: () => fixedNow);
        final LifeOrganizationController orgCtrl = LifeOrganizationController(
          repository: orgRepo,
          clock: () => fixedNow,
          initialUserId: 'usr_a',
          initialCurrency: SupportedCurrency.php,
        );
        await orgCtrl.loadAll();

        await orgCtrl.createShoppingList(title: 'Groceries');
        final String listId = orgCtrl.shoppingLists.single.id;

        // 2 packs * ₱125.50 = ₱251.00 (25100 minor)
        await orgCtrl.addShoppingProduct(
          shoppingListId: listId,
          name: 'Oats',
          quantity: 2,
          unit: ShoppingUnit.pack,
          estimatedUnitPriceMinor: 12550,
        );
        // 3 bottles * ₱40.00 = ₱120.00 (12000 minor)
        await orgCtrl.addShoppingProduct(
          shoppingListId: listId,
          name: 'Juice',
          quantity: 3,
          unit: ShoppingUnit.bottle,
          estimatedUnitPriceMinor: 4000,
        );

        ShoppingList list = orgCtrl.shoppingLists.single;
        expect(list.estimatedTotalMinor, 37100);
        expect(list.remainingTotalMinor, 37100);

        // Marking Oats purchased reduces Remaining to ₱120.00, keeps Est. Total ₱371.00.
        await orgCtrl.toggleShoppingProductPurchased(
          shoppingListId: listId,
          productId: list.items.first.id,
          isPurchased: true,
        );
        list = orgCtrl.shoppingLists.single;
        expect(list.estimatedTotalMinor, 37100);
        expect(list.remainingTotalMinor, 12000);
        expect(list.purchasedCount, 1);

        // Actual Money expenses MUST remain zero.
        expect(moneyCtrl.currentOverview.totalExpensesMinor, 0);

        moneyCtrl.dispose();
        orgCtrl.dispose();
      },
    );

    test('validates quantity and estimated shopping unit prices', () {
      expect(LifeOrganizationValidators.validateQuantityInput('0'), isNotNull);
      expect(LifeOrganizationValidators.validateQuantityInput('2'), isNull);
      expect(
        LifeOrganizationValidators.validateEstimatedPriceInput(
          '-10',
          SupportedCurrency.php,
        ),
        isNotNull,
      );
      expect(
        LifeOrganizationValidators.validateEstimatedPriceInput(
          'NaN',
          SupportedCurrency.php,
        ),
        isNotNull,
      );
      expect(
        LifeOrganizationValidators.validateEstimatedPriceInput(
          '49.99',
          SupportedCurrency.php,
        ),
        isNull,
      );
    });
  });

  group('LifeOrganization RLS Ownership & Logout Cache Isolation', () {
    test('denies cross-account access and clears checklists, routines, and shopping lists on logout', () async {
      final DateTime fixedNow = DateTime.utc(2026, 11, 16, 10, 0);
      final InMemoryLifeOrganizationRepository repo =
          InMemoryLifeOrganizationRepository(clock: () => fixedNow);

      final SmartChecklist chk = await repo.createChecklist(
        authenticatedUserId: 'usr_a',
        title: 'Private Packing',
      );
      final DailyRoutine rtn = await repo.createRoutine(
        authenticatedUserId: 'usr_a',
        title: 'Private Evening',
        scheduledWeekdays: const <int>{1, 2, 3},
      );
      final ShoppingList shp = await repo.createShoppingList(
        authenticatedUserId: 'usr_a',
        title: 'Private Market',
        currency: SupportedCurrency.php,
      );

      expect(
        () => repo.deleteChecklist(
          authenticatedUserId: 'usr_b',
          checklistId: chk.id,
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(
        () => repo.addRoutineStep(
          authenticatedUserId: 'usr_b',
          routineId: rtn.id,
          title: 'Injected step',
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(
        () => repo.deleteShoppingList(
          authenticatedUserId: 'usr_b',
          shoppingListId: shp.id,
        ),
        throwsA(isA<AuthFailure>()),
      );

      final LifeOrganizationController ctrl = LifeOrganizationController(
        repository: repo,
        clock: () => fixedNow,
      );
      await ctrl.bindAuthenticatedUser('usr_a');
      expect(ctrl.checklists.length, 1);
      expect(ctrl.routines.length, 1);
      expect(ctrl.shoppingLists.length, 1);

      // Logout clears all three caches immediately.
      await ctrl.bindAuthenticatedUser(null);
      expect(ctrl.checklists, isEmpty);
      expect(ctrl.routines, isEmpty);
      expect(ctrl.shoppingLists, isEmpty);

      await ctrl.bindAuthenticatedUser('usr_b');
      expect(ctrl.checklists, isEmpty);
      expect(ctrl.routines, isEmpty);
      expect(ctrl.shoppingLists, isEmpty);

      ctrl.dispose();
    });
  });
}
