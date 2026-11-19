import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/assistant/domain/assistant_models.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/checklists/domain/smart_checklist.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/routines/domain/daily_routine.dart';
import 'package:kaya/features/shopping/domain/shopping_list.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';

/// Immutable, account-scoped cross-domain context snapshot for Phase 8 Assistant.
///
/// Every domain slice preserves explicit [DomainReadState] so retrieval failures
/// are never misinterpreted as empty records.
/// Privacy rule: [toString] reports only status flags and counts, never private data.
class AssistantContextSnapshot {
  const AssistantContextSnapshot({
    required this.authenticatedUserId,
    this.userDisplayName,
    required this.activeCurrency,
    required this.referenceToday,
    required this.tasks,
    required this.moneyOverview,
    required this.bills,
    required this.reminders,
    required this.documents,
    required this.routines,
    required this.checklists,
    required this.shoppingLists,
  });

  final String? authenticatedUserId;
  final String? userDisplayName;
  final SupportedCurrency activeCurrency;
  final KayaDateOnly referenceToday;

  final DomainReadState<List<TaskItem>> tasks;
  final DomainReadState<FinancialOverviewSummary> moneyOverview;
  final DomainReadState<List<BillItem>> bills;
  final DomainReadState<List<ReminderItem>> reminders;
  final DomainReadState<List<VaultDocument>> documents;
  final DomainReadState<List<DailyRoutine>> routines;
  final DomainReadState<List<SmartChecklist>> checklists;
  final DomainReadState<List<ShoppingList>> shoppingLists;

  bool get isAuthenticated =>
      authenticatedUserId != null && authenticatedUserId!.trim().isNotEmpty;

  /// All core assistant domains currently reporting a retrieval failure.
  List<AssistantSourceDomain> get failedDomains {
    final List<AssistantSourceDomain> failed = <AssistantSourceDomain>[];
    if (tasks.isFailed) {
      failed.add(AssistantSourceDomain.tasks);
    }
    if (moneyOverview.isFailed) {
      failed.add(AssistantSourceDomain.money);
    }
    if (bills.isFailed) {
      failed.add(AssistantSourceDomain.bills);
    }
    if (reminders.isFailed) {
      failed.add(AssistantSourceDomain.reminders);
    }
    if (documents.isFailed) {
      failed.add(AssistantSourceDomain.documents);
    }
    if (routines.isFailed) {
      failed.add(AssistantSourceDomain.routines);
    }
    return List<AssistantSourceDomain>.unmodifiable(failed);
  }

  bool get hasAnyFailure => failedDomains.isNotEmpty;

  List<TaskItem> get _allTasks => tasks.data ?? const <TaskItem>[];

  List<TaskItem> get overdueTasks => _allTasks
      .where((TaskItem t) => t.isOverdue(referenceToday))
      .toList(growable: false);

  List<TaskItem> get todayTasks => _allTasks
      .where((TaskItem t) => t.isDueToday(referenceToday))
      .toList(growable: false);

  List<TaskItem> get activeTasks =>
      _allTasks.where((TaskItem t) => !t.isCompleted).toList(growable: false);

  List<BillItem> get _allBills => bills.data ?? const <BillItem>[];

  List<BillItem> get unpaidBills =>
      _allBills.where((BillItem b) => !b.isPaid).toList(growable: false);

  List<BillItem> get overdueBills => _allBills
      .where((BillItem b) => b.isOverdue(referenceToday))
      .toList(growable: false);

  List<BillItem> get dueTodayBills => _allBills
      .where((BillItem b) => b.isDueToday(referenceToday))
      .toList(growable: false);

  /// Unpaid bills that are overdue, due today, or due within the next 7 days,
  /// ordered deterministically by [BillItem.compareByUrgency].
  List<BillItem> get dueSoonBills {
    final List<BillItem> filtered = unpaidBills
        .where(
          (BillItem b) => b.dueDate.daysDifferenceFrom(referenceToday) <= 7,
        )
        .toList();
    filtered.sort(
      (BillItem a, BillItem b) =>
          BillItem.compareByUrgency(a, b, referenceToday),
    );
    return List<BillItem>.unmodifiable(filtered);
  }

  List<ReminderItem> get _allReminders =>
      reminders.data ?? const <ReminderItem>[];

  List<ReminderItem> get overdueReminders => _allReminders
      .where((ReminderItem r) => r.isOverdue(referenceToday))
      .toList(growable: false);

  List<ReminderItem> get todayReminders => _allReminders
      .where((ReminderItem r) => r.isDueToday(referenceToday))
      .toList(growable: false);

  List<VaultDocument> get _allDocuments =>
      documents.data ?? const <VaultDocument>[];

  List<VaultDocument> get expiredDocuments => _allDocuments
      .where((VaultDocument d) => d.isExpired(referenceToday))
      .toList(growable: false);

  List<VaultDocument> get expiringSoonDocuments => _allDocuments
      .where((VaultDocument d) => d.isExpiringSoon(referenceToday))
      .toList(growable: false);

  List<DailyRoutine> get _allRoutines =>
      routines.data ?? const <DailyRoutine>[];

  List<DailyRoutine> get todayScheduledRoutines => _allRoutines
      .where((DailyRoutine r) => r.isScheduledOn(referenceToday))
      .toList(growable: false);

  List<DailyRoutine> get incompleteTodayRoutines => todayScheduledRoutines
      .where((DailyRoutine r) => !r.isCompletedOn(referenceToday))
      .toList(growable: false);

  @override
  String toString() =>
      'AssistantContextSnapshot(authenticated: $isAuthenticated, '
      'tasks: ${tasks.status.name}(${_allTasks.length}), '
      'money: ${moneyOverview.status.name}, '
      'bills: ${bills.status.name}(${_allBills.length}), '
      'reminders: ${reminders.status.name}(${_allReminders.length}), '
      'docs: ${documents.status.name}(${_allDocuments.length}), '
      'routines: ${routines.status.name}(${_allRoutines.length}))';
}
