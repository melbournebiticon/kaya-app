import 'package:kaya/app/router/kaya_destination.dart';
import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/responsive_layout.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:kaya/features/auth/domain/user_profile.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/bills/presentation/bill_card_tile.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/reminders/presentation/reminder_card_tile.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';
import 'package:kaya/features/tasks/presentation/quick_add_task_bar.dart';
import 'package:kaya/features/tasks/presentation/task_card_tile.dart';
import 'package:material_ui/material_ui.dart';

/// Core questions defined in Section 1 of the KAYA Master Blueprint.
class _CoreQuestionItem {
  const _CoreQuestionItem({
    required this.question,
    required this.moduleLabel,
    required this.targetModule,
    required this.icon,
  });

  final String question;
  final String moduleLabel;
  final KayaModule targetModule;
  final IconData icon;
}

/// Today module screen (Phases 1–6 Integration).
///
/// Displays the daily overview layout, authenticated user context, centralized
/// Safe to Spend summary, expiring documents badge, Today's Priority Queue
/// (tasks, bills, reminders), Most Important Task, and the 7 core KAYA questions.
class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.onSelectModule,
    this.profile,
    this.taskController,
    this.moneyController,
    this.billController,
    this.reminderController,
    this.lifeVaultController,
    this.lifeOrganizationController,
  });

  final ValueChanged<KayaModule> onSelectModule;
  final UserProfile? profile;
  final TaskController? taskController;
  final MoneyController? moneyController;
  final BillController? billController;
  final ReminderController? reminderController;
  final LifeVaultController? lifeVaultController;
  final LifeOrganizationController? lifeOrganizationController;

  static const List<_CoreQuestionItem> _coreQuestions = <_CoreQuestionItem>[
    _CoreQuestionItem(
      question: 'What should I do today?',
      moduleLabel: 'Life • Tasks',
      targetModule: KayaModule.life,
      icon: Icons.check_circle_outline,
    ),
    _CoreQuestionItem(
      question: 'What is my most important task?',
      moduleLabel: 'Life • Priorities',
      targetModule: KayaModule.life,
      icon: Icons.flag_outlined,
    ),
    _CoreQuestionItem(
      question: 'Do I have upcoming bills?',
      moduleLabel: 'Life • Bills',
      targetModule: KayaModule.life,
      icon: Icons.receipt_long_outlined,
    ),
    _CoreQuestionItem(
      question: 'How much can I safely spend?',
      moduleLabel: 'Money • Safe to Spend',
      targetModule: KayaModule.money,
      icon: Icons.account_balance_wallet_outlined,
    ),
    _CoreQuestionItem(
      question: 'Are my documents expiring?',
      moduleLabel: 'Life • Life Vault',
      targetModule: KayaModule.life,
      icon: Icons.badge_outlined,
    ),
    _CoreQuestionItem(
      question: 'Am I keeping up with my routines?',
      moduleLabel: 'Life • Routines',
      targetModule: KayaModule.life,
      icon: Icons.repeat_outlined,
    ),
    _CoreQuestionItem(
      question: 'What should I focus on next?',
      moduleLabel: 'KAYA Assistant',
      targetModule: KayaModule.assistant,
      icon: Icons.auto_awesome_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Listenable> listenables = <Listenable>[
      ?taskController,
      ?moneyController,
      ?billController,
      ?reminderController,
      ?lifeVaultController,
      ?lifeOrganizationController,
    ];
    if (listenables.isEmpty) {
      return _buildBody(context, null, null, null, null, null, null);
    }
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (BuildContext context, _) => _buildBody(
        context,
        taskController,
        moneyController,
        billController,
        reminderController,
        lifeVaultController,
        lifeOrganizationController,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TaskController? ctrl,
    MoneyController? moneyCtrl,
    BillController? billCtrl,
    ReminderController? remCtrl,
    LifeVaultController? vaultCtrl,
    LifeOrganizationController? orgCtrl,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<TaskItem> priorityTasks =
        ctrl?.todayPriorityQueue ?? <TaskItem>[];
    final List<BillItem> priorityBills =
        billCtrl?.todayPriorityBills ?? <BillItem>[];
    final List<ReminderItem> priorityReminders =
        remCtrl?.todayPriorityReminders ?? <ReminderItem>[];
    final bool hasPriorityItems =
        priorityTasks.isNotEmpty ||
        priorityBills.isNotEmpty ||
        priorityReminders.isNotEmpty;

    final TaskItem? topTask = ctrl?.mostImportantTask;
    final int overdueCount =
        (ctrl?.overdueTasks.length ?? 0) +
        (billCtrl?.overdueBills.length ?? 0) +
        (remCtrl?.overdueReminders.length ?? 0) +
        (vaultCtrl?.expiredDocuments.length ?? 0);
    final int upcomingBillsCount = billCtrl?.upcomingBills.length ?? 0;
    final int expiredDocsCount = vaultCtrl?.expiredDocuments.length ?? 0;
    final int expiringSoonDocsCount =
        vaultCtrl?.expiringSoonDocuments.length ?? 0;
    final int scheduledRoutinesToday =
        orgCtrl?.todayScheduledRoutines.length ?? 0;
    final int completedRoutinesToday =
        orgCtrl?.completedTodayRoutinesCount ?? 0;
    final FinancialOverviewSummary? moneyOverview = moneyCtrl?.currentOverview;

    return KayaResponsiveScaffoldBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          KayaCard(
            highlighted: overdueCount > 0,
            padding: AppSpacing.cardPaddingLarge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Today Overview',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (profile != null)
                      Flexible(
                        child: Text(
                          '${profile!.displayName} • ${profile!.preferredCurrency.code}',
                          style: textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Your Life, Clearer.', style: textTheme.displaySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  overdueCount > 0
                      ? 'You have $overdueCount overdue item${overdueCount == 1 ? '' : 's'} to review today.'
                      : (hasPriorityItems
                            ? 'Everything due today is queued below.'
                            : 'Nothing urgent on your plate yet. Add a task, bill, or balance whenever you are ready.'),
                  style: textTheme.bodyMedium,
                ),
                if (overdueCount > 0 ||
                    (moneyOverview != null && moneyOverview.hasAnyActivity) ||
                    upcomingBillsCount > 0 ||
                    expiredDocsCount > 0 ||
                    expiringSoonDocsCount > 0 ||
                    scheduledRoutinesToday > 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      if (overdueCount > 0)
                        KayaStatusBadge(
                          label: '$overdueCount overdue',
                          type: KayaStatusType.critical,
                          customIcon: Icons.warning_amber_outlined,
                        ),
                      if (moneyOverview != null && moneyOverview.hasAnyActivity)
                        KayaStatusBadge(
                          key: const ValueKey<String>(
                            'today_safe_to_spend_badge',
                          ),
                          label:
                              'Safe to Spend: ${MoneyFormatter.formatMinorUnits(moneyOverview.safeToSpendMinor, moneyOverview.currency)}',
                          type: switch (moneyOverview.health) {
                            SafeToSpendHealth.healthy =>
                              KayaStatusType.positive,
                            SafeToSpendHealth.caution => KayaStatusType.warning,
                            SafeToSpendHealth.critical =>
                              KayaStatusType.critical,
                            SafeToSpendHealth.unconfigured =>
                              KayaStatusType.neutral,
                          },
                          customIcon: Icons.account_balance_wallet_outlined,
                        ),
                      if (upcomingBillsCount > 0)
                        KayaStatusBadge(
                          key: const ValueKey<String>(
                            'today_upcoming_bills_badge',
                          ),
                          label: upcomingBillsCount == 1
                              ? '1 upcoming bill'
                              : '$upcomingBillsCount upcoming bills',
                          type: KayaStatusType.info,
                          customIcon: Icons.receipt_long_outlined,
                        ),
                      if (expiredDocsCount > 0 || expiringSoonDocsCount > 0)
                        KayaStatusBadge(
                          key: const ValueKey<String>(
                            'today_expiring_docs_badge',
                          ),
                          label: expiredDocsCount > 0
                              ? '$expiredDocsCount expired docs'
                              : (expiringSoonDocsCount == 1
                                    ? '1 expiring doc'
                                    : '$expiringSoonDocsCount expiring docs'),
                          type: expiredDocsCount > 0
                              ? KayaStatusType.critical
                              : KayaStatusType.warning,
                          customIcon: Icons.badge_outlined,
                        ),
                      if (scheduledRoutinesToday > 0)
                        KayaStatusBadge(
                          key: const ValueKey<String>('today_routines_badge'),
                          label:
                              'Routines today: $completedRoutinesToday/$scheduledRoutinesToday',
                          type: completedRoutinesToday == scheduledRoutinesToday
                              ? KayaStatusType.positive
                              : KayaStatusType.info,
                          customIcon: Icons.repeat_outlined,
                        ),
                    ],
                  ),
                ],
                if (topTask != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.star_outline,
                          size: 18,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Most Important Task',
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(topTask.title, style: textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (ctrl != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            QuickAddTaskBar(controller: ctrl),
          ],
          const SizedBox(height: AppSpacing.lg),
          KayaSectionHeader(
            title: 'Today\'s Focus',
            subtitle: 'Tasks, bills, and reminders due today or overdue',
            trailing: hasPriorityItems
                ? KayaButton(
                    label: 'View in Life',
                    variant: KayaButtonVariant.ghost,
                    onPressed: () => onSelectModule(KayaModule.life),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!hasPriorityItems)
            KayaEmptyState(
              icon: Icons.task_alt_outlined,
              title: 'No Priorities Scheduled for Today',
              description: 'You have no tasks, bills, or reminders recorded yet. Explore the Life or Money modules to see where your daily items will be organized.',
              actionLabel: 'Open Life Module',
              onAction: () => onSelectModule(KayaModule.life),
            )
          else
            Column(
              children: <Widget>[
                if (billCtrl != null)
                  for (final BillItem bill in priorityBills) ...<Widget>[
                    BillCardTile(
                      key: ValueKey<String>('today_bill_card_${bill.id}'),
                      bill: bill,
                      controller: billCtrl,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                if (remCtrl != null)
                  for (final ReminderItem rem in priorityReminders) ...<Widget>[
                    ReminderCardTile(
                      key: ValueKey<String>('today_reminder_card_${rem.id}'),
                      reminder: rem,
                      controller: remCtrl,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                if (ctrl != null)
                  for (final TaskItem item in priorityTasks) ...<Widget>[
                    TaskCardTile(
                      key: ValueKey<String>('today_task_card_${item.id}'),
                      task: item,
                      controller: ctrl,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          const KayaSectionHeader(
            title: 'Quick Jump',
            subtitle: 'Where would you like to check next?',
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = KayaResponsive.gridColumnsForWidth(
                constraints.maxWidth,
              );
              if (columns == 1) {
                return Column(
                  children: <Widget>[
                    for (final _CoreQuestionItem item
                        in _coreQuestions) ...<Widget>[
                      _CoreQuestionCard(
                        item: item,
                        onTap: () => onSelectModule(item.targetModule),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              }

              const double spacing = AppSpacing.md;
              final double itemWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: <Widget>[
                  for (final _CoreQuestionItem item in _coreQuestions)
                    SizedBox(
                      width: itemWidth,
                      child: _CoreQuestionCard(
                        item: item,
                        onTap: () => onSelectModule(item.targetModule),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CoreQuestionCard extends StatelessWidget {
  const _CoreQuestionCard({required this.item, required this.onTap});

  final _CoreQuestionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return KayaCard(
      onTap: onTap,
      semanticLabel: '${item.question} - ${item.moduleLabel}',
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.question, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  item.moduleLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
