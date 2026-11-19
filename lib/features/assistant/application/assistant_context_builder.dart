import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/assistant/domain/assistant_context_snapshot.dart';
import 'package:kaya/features/assistant/domain/assistant_models.dart';
import 'package:kaya/features/auth/application/auth_controller.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/checklists/domain/smart_checklist.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/shopping/domain/shopping_list.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';

/// Builds an immutable, account-isolated [AssistantContextSnapshot] from
/// live Phase 2–7 controllers without duplicating business formulas.
class AssistantContextBuilder {
  AssistantContextBuilder({
    this.authController,
    this.taskController,
    this.moneyController,
    this.billController,
    this.reminderController,
    this.lifeVaultController,
    this.lifeOrganizationController,
    this.clock,
  });

  final AuthController? authController;
  final TaskController? taskController;
  final MoneyController? moneyController;
  final BillController? billController;
  final ReminderController? reminderController;
  final LifeVaultController? lifeVaultController;
  final LifeOrganizationController? lifeOrganizationController;
  final DateTime Function()? clock;

  /// Collects verified read states scoped strictly to [activeUserId].
  ///
  /// Any controller bound to a different user fails closed as
  /// [DomainReadState.unauthenticated].
  AssistantContextSnapshot build({required String? activeUserId}) {
    final String? uid = (activeUserId?.trim().isEmpty ?? true)
        ? null
        : activeUserId!.trim();
    final KayaDateOnly today = clock != null
        ? KayaDateOnly.fromDateTime(clock!())
        : (taskController?.referenceToday ??
              moneyController?.referenceToday ??
              billController?.referenceToday ??
              reminderController?.referenceToday ??
              lifeVaultController?.referenceToday ??
              lifeOrganizationController?.referenceToday ??
              KayaDateOnly.fromDateTime(DateTime.now()));
    final SupportedCurrency currency =
        moneyController?.activeCurrency ??
        billController?.activeCurrency ??
        authController?.profile?.preferredCurrency ??
        SupportedCurrency.php;

    if (uid == null) {
      return AssistantContextSnapshot(
        authenticatedUserId: null,
        userDisplayName: null,
        activeCurrency: currency,
        referenceToday: today,
        tasks: const DomainReadState<List<TaskItem>>.unauthenticated(),
        moneyOverview:
            const DomainReadState<FinancialOverviewSummary>.unauthenticated(),
        bills: const DomainReadState<List<BillItem>>.unauthenticated(),
        reminders: const DomainReadState<List<ReminderItem>>.unauthenticated(),
        documents: const DomainReadState<List<VaultDocument>>.unauthenticated(),
        routines: const DomainReadState<List<DailyRoutine>>.unauthenticated(),
        checklists:
            const DomainReadState<List<SmartChecklist>>.unauthenticated(),
        shoppingLists:
            const DomainReadState<List<ShoppingList>>.unauthenticated(),
      );
    }

    final String? displayName = authController?.profile?.userId == uid
        ? authController?.profile?.displayName
        : null;

    return AssistantContextSnapshot(
      authenticatedUserId: uid,
      userDisplayName: displayName,
      activeCurrency: currency,
      referenceToday: today,
      tasks: _readTasks(uid),
      moneyOverview: _readMoneyOverview(uid, today, currency),
      bills: _readBills(uid),
      reminders: _readReminders(uid),
      documents: _readDocuments(uid),
      routines: _readRoutines(uid),
      checklists: _readChecklists(uid),
      shoppingLists: _readShoppingLists(uid),
    );
  }

  DomainReadState<List<TaskItem>> _readTasks(String uid) {
    final TaskController? ctrl = taskController;
    if (ctrl == null) {
      return const DomainReadState<List<TaskItem>>.ready(<TaskItem>[]);
    }
    if (ctrl.activeUserId != uid) {
      return const DomainReadState<List<TaskItem>>.unauthenticated();
    }
    if (ctrl.hasLoadError) {
      return DomainReadState<List<TaskItem>>.failed(ctrl.errorMessage);
    }
    if (ctrl.isLoading) {
      return const DomainReadState<List<TaskItem>>.loading();
    }
    return DomainReadState<List<TaskItem>>.ready(ctrl.allTasks);
  }

  DomainReadState<FinancialOverviewSummary> _readMoneyOverview(
    String uid,
    KayaDateOnly today,
    SupportedCurrency currency,
  ) {
    final MoneyController? ctrl = moneyController;
    if (ctrl == null) {
      return DomainReadState<FinancialOverviewSummary>.ready(
        SafeToSpendCalculator.calculateOverview(
          transactions: const <MoneyTransaction>[],
          year: today.year,
          month: today.month,
          currency: currency,
        ),
      );
    }
    if (ctrl.activeUserId != uid) {
      return const DomainReadState<FinancialOverviewSummary>.unauthenticated();
    }
    if (ctrl.hasLoadError) {
      return DomainReadState<FinancialOverviewSummary>.failed(
        ctrl.errorMessage,
      );
    }
    if (ctrl.isLoading) {
      return const DomainReadState<FinancialOverviewSummary>.loading();
    }
    // Reuses the single authoritative MoneyController / SafeToSpendCalculator output.
    return DomainReadState<FinancialOverviewSummary>.ready(
      ctrl.currentOverview,
    );
  }

  DomainReadState<List<BillItem>> _readBills(String uid) {
    final BillController? ctrl = billController;
    if (ctrl == null) {
      return const DomainReadState<List<BillItem>>.ready(<BillItem>[]);
    }
    if (ctrl.activeUserId != uid) {
      return const DomainReadState<List<BillItem>>.unauthenticated();
    }
    if (ctrl.hasLoadError) {
      return DomainReadState<List<BillItem>>.failed(ctrl.errorMessage);
    }
    if (ctrl.isLoading) {
      return const DomainReadState<List<BillItem>>.loading();
    }
    return DomainReadState<List<BillItem>>.ready(ctrl.allBills);
  }

  DomainReadState<List<ReminderItem>> _readReminders(String uid) {
    final ReminderController? ctrl = reminderController;
    if (ctrl == null) {
      return const DomainReadState<List<ReminderItem>>.ready(<ReminderItem>[]);
    }
    if (ctrl.activeUserId != uid) {
      return const DomainReadState<List<ReminderItem>>.unauthenticated();
    }
    if (ctrl.hasLoadError) {
      return DomainReadState<List<ReminderItem>>.failed(ctrl.errorMessage);
    }
    if (ctrl.isLoading) {
      return const DomainReadState<List<ReminderItem>>.loading();
    }
    return DomainReadState<List<ReminderItem>>.ready(ctrl.allReminders);
  }

  DomainReadState<List<VaultDocument>> _readDocuments(String uid) {
    final LifeVaultController? ctrl = lifeVaultController;
    if (ctrl == null) {
      return const DomainReadState<List<VaultDocument>>.ready(
        <VaultDocument>[],
      );
    }
    if (ctrl.activeUserId != uid) {
      return const DomainReadState<List<VaultDocument>>.unauthenticated();
    }
    if (ctrl.hasLoadError) {
      return DomainReadState<List<VaultDocument>>.failed(ctrl.errorMessage);
    }
    if (ctrl.isLoading) {
      return const DomainReadState<List<VaultDocument>>.loading();
    }
    return DomainReadState<List<VaultDocument>>.ready(ctrl.allDocuments);
  }

  DomainReadState<List<DailyRoutine>> _readRoutines(String uid) {
    final LifeOrganizationController? ctrl = lifeOrganizationController;
    if (ctrl == null) {
      return const DomainReadState<List<DailyRoutine>>.ready(<DailyRoutine>[]);
    }
    if (ctrl.activeUserId != uid) {
      return const DomainReadState<List<DailyRoutine>>.unauthenticated();
    }
    if (ctrl.hasLoadError) {
      return DomainReadState<List<DailyRoutine>>.failed(ctrl.errorMessage);
    }
    if (ctrl.isLoading) {
      return const DomainReadState<List<DailyRoutine>>.loading();
    }
    return DomainReadState<List<DailyRoutine>>.ready(ctrl.routines);
  }

  DomainReadState<List<SmartChecklist>> _readChecklists(String uid) {
    final LifeOrganizationController? ctrl = lifeOrganizationController;
    if (ctrl == null) {
      return const DomainReadState<List<SmartChecklist>>.ready(
        <SmartChecklist>[],
      );
    }
    if (ctrl.activeUserId != uid) {
      return const DomainReadState<List<SmartChecklist>>.unauthenticated();
    }
    if (ctrl.hasLoadError) {
      return DomainReadState<List<SmartChecklist>>.failed(ctrl.errorMessage);
    }
    if (ctrl.isLoading) {
      return const DomainReadState<List<SmartChecklist>>.loading();
    }
    return DomainReadState<List<SmartChecklist>>.ready(ctrl.checklists);
  }

  DomainReadState<List<ShoppingList>> _readShoppingLists(String uid) {
    final LifeOrganizationController? ctrl = lifeOrganizationController;
    if (ctrl == null) {
      return const DomainReadState<List<ShoppingList>>.ready(<ShoppingList>[]);
    }
    if (ctrl.activeUserId != uid) {
      return const DomainReadState<List<ShoppingList>>.unauthenticated();
    }
    if (ctrl.hasLoadError) {
      return DomainReadState<List<ShoppingList>>.failed(ctrl.errorMessage);
    }
    if (ctrl.isLoading) {
      return const DomainReadState<List<ShoppingList>>.loading();
    }
    return DomainReadState<List<ShoppingList>>.ready(ctrl.shoppingLists);
  }

  /// Triggers safe reloads for failed domains (or all failing domains if
  /// [domains] is empty or includes [AssistantSourceDomain.system]).
  Future<void> retryFailedDomains(List<AssistantSourceDomain> domains) async {
    final bool retryAllFailed =
        domains.isEmpty || domains.contains(AssistantSourceDomain.system);
    final List<Future<void>> tasks = <Future<void>>[];

    if ((retryAllFailed && (taskController?.hasLoadError ?? false)) ||
        domains.contains(AssistantSourceDomain.tasks)) {
      final TaskController? ctrl = taskController;
      if (ctrl != null) {
        tasks.add(ctrl.loadTasks());
      }
    }
    if ((retryAllFailed && (moneyController?.hasLoadError ?? false)) ||
        domains.contains(AssistantSourceDomain.money)) {
      final MoneyController? ctrl = moneyController;
      if (ctrl != null) {
        tasks.add(ctrl.loadMoneyData());
      }
    }
    if ((retryAllFailed && (billController?.hasLoadError ?? false)) ||
        domains.contains(AssistantSourceDomain.bills)) {
      final BillController? ctrl = billController;
      if (ctrl != null) {
        tasks.add(ctrl.loadBills());
      }
    }
    if ((retryAllFailed && (reminderController?.hasLoadError ?? false)) ||
        domains.contains(AssistantSourceDomain.reminders)) {
      final ReminderController? ctrl = reminderController;
      if (ctrl != null) {
        tasks.add(ctrl.loadReminders());
      }
    }
    if ((retryAllFailed && (lifeVaultController?.hasLoadError ?? false)) ||
        domains.contains(AssistantSourceDomain.documents)) {
      final LifeVaultController? ctrl = lifeVaultController;
      if (ctrl != null) {
        tasks.add(ctrl.loadVault());
      }
    }
    if ((retryAllFailed &&
            (lifeOrganizationController?.hasLoadError ?? false)) ||
        domains.contains(AssistantSourceDomain.routines)) {
      final LifeOrganizationController? ctrl = lifeOrganizationController;
      if (ctrl != null) {
        tasks.add(ctrl.loadAll());
      }
    }

    if (tasks.isNotEmpty) {
      await Future.wait<void>(tasks);
    }
  }
}
