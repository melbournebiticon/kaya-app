import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/responsive_layout.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/presentation/bills_reminders_workspace_section.dart';
import 'package:kaya/features/checklists/presentation/checklists_workspace_section.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/presentation/life_vault_workspace_section.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/presentation/routines_workspace_section.dart';
import 'package:kaya/features/shopping/presentation/shopping_workspace_section.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/presentation/tasks_workspace_section.dart';
import 'package:material_ui/material_ui.dart';

/// Top-level workspace sub-tabs inside the Life module.
enum LifeWorkspaceTab {
  tasks(label: 'Tasks', keyName: 'life_subtab_tasks'),
  billsAndReminders(label: 'Bills & Reminders', keyName: 'life_subtab_bills'),
  lifeVault(label: 'Life Vault', keyName: 'life_subtab_vault'),
  routines(label: 'Routines', keyName: 'life_subtab_routines'),
  checklists(label: 'Checklists', keyName: 'life_subtab_checklists'),
  shopping(label: 'Shopping', keyName: 'life_subtab_shopping'),
  overview(label: 'All Areas', keyName: 'life_subtab_domains');

  const LifeWorkspaceTab({required this.label, required this.keyName});

  final String label;
  final String keyName;
}

class _LifeDomainInfo {
  const _LifeDomainInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.statusLabel,
    this.statusType = KayaStatusType.neutral,
    this.targetTab,
  });

  final String title;
  final String description;
  final IconData icon;
  final String statusLabel;
  final KayaStatusType statusType;
  final LifeWorkspaceTab? targetTab;
}

/// Life module screen organized into focused workspace sub-tabs.
class LifeScreen extends StatefulWidget {
  const LifeScreen({
    super.key,
    this.taskController,
    this.billController,
    this.reminderController,
    this.lifeVaultController,
    this.lifeOrganizationController,
    this.initialTab = LifeWorkspaceTab.tasks,
  });

  final TaskController? taskController;
  final BillController? billController;
  final ReminderController? reminderController;
  final LifeVaultController? lifeVaultController;
  final LifeOrganizationController? lifeOrganizationController;
  final LifeWorkspaceTab initialTab;

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> {
  late LifeWorkspaceTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  List<_LifeDomainInfo> _buildDomains(
    TaskController? ctrl,
    BillController? billCtrl,
    ReminderController? remCtrl,
    LifeVaultController? vaultCtrl,
    LifeOrganizationController? orgCtrl,
  ) {
    final int activeTaskCount = ctrl?.activeTasks.length ?? 0;
    final int overdueCount = ctrl?.overdueTasks.length ?? 0;
    final String taskStatus = overdueCount > 0
        ? '$activeTaskCount active ($overdueCount overdue)'
        : '$activeTaskCount active tasks';

    final int unpaidBillCount = billCtrl?.unpaidBills.length ?? 0;
    final int overdueBillCount = billCtrl?.overdueBills.length ?? 0;
    final int activeReminderCount = remCtrl?.activeReminders.length ?? 0;
    final String billReminderStatus = overdueBillCount > 0
        ? '$unpaidBillCount unpaid ($overdueBillCount overdue)'
        : '$unpaidBillCount unpaid • $activeReminderCount reminders';

    final int docCount = vaultCtrl?.allDocuments.length ?? 0;
    final int itemCount = vaultCtrl?.allBelongings.length ?? 0;
    final int expiredDocCount = vaultCtrl?.expiredDocuments.length ?? 0;
    final int expiringSoonDocCount =
        vaultCtrl?.expiringSoonDocuments.length ?? 0;
    final String vaultStatus;
    if (expiredDocCount > 0) {
      vaultStatus = '$docCount docs ($expiredDocCount expired)';
    } else if (expiringSoonDocCount > 0) {
      vaultStatus = '$docCount docs ($expiringSoonDocCount expiring soon)';
    } else if (docCount > 0 || itemCount > 0) {
      vaultStatus = '$docCount docs • $itemCount items';
    } else {
      vaultStatus = 'Vault empty';
    }

    return <_LifeDomainInfo>[
      _LifeDomainInfo(
        title: 'Tasks & Responsibilities',
        description: 'Due dates, priorities, categories, and Today/Upcoming/Overdue views.',
        icon: Icons.task_alt_outlined,
        statusLabel: taskStatus,
        statusType: overdueCount > 0
            ? KayaStatusType.critical
            : (activeTaskCount > 0
                  ? KayaStatusType.positive
                  : KayaStatusType.neutral),
        targetTab: LifeWorkspaceTab.tasks,
      ),
      _LifeDomainInfo(
        title: 'Bills & Reminders',
        description: 'Paid/unpaid obligations, due date tracking, and recurring reminders.',
        icon: Icons.event_available_outlined,
        statusLabel: billReminderStatus,
        statusType: overdueBillCount > 0
            ? KayaStatusType.critical
            : ((unpaidBillCount > 0 || activeReminderCount > 0)
                  ? KayaStatusType.warning
                  : KayaStatusType.neutral),
        targetTab: LifeWorkspaceTab.billsAndReminders,
      ),
      _LifeDomainInfo(
        title: 'Life Vault',
        description: 'Important documents, expiration alerts, physical locations, and lent/borrowed items.',
        icon: Icons.lock_outline,
        statusLabel: vaultStatus,
        statusType: expiredDocCount > 0
            ? KayaStatusType.critical
            : (expiringSoonDocCount > 0
                  ? KayaStatusType.warning
                  : ((docCount > 0 || itemCount > 0)
                        ? KayaStatusType.positive
                        : KayaStatusType.neutral)),
        targetTab: LifeWorkspaceTab.lifeVault,
      ),
      _LifeDomainInfo(
        title: 'Daily Routines',
        description: 'Scheduled days, step-by-step completion tracking, and consistency streaks.',
        icon: Icons.repeat_outlined,
        statusLabel:
            '${orgCtrl?.routines.length ?? 0} routines (${orgCtrl?.completedTodayRoutinesCount ?? 0}/${orgCtrl?.todayScheduledRoutines.length ?? 0} today)',
        statusType:
            (orgCtrl != null &&
                orgCtrl.todayScheduledRoutines.isNotEmpty &&
                orgCtrl.completedTodayRoutinesCount ==
                    orgCtrl.todayScheduledRoutines.length)
            ? KayaStatusType.positive
            : KayaStatusType.neutral,
        targetTab: LifeWorkspaceTab.routines,
      ),
      _LifeDomainInfo(
        title: 'Smart Checklists',
        description: 'Reusable packing, errand, and preparation checklists with quick reset.',
        icon: Icons.checklist_outlined,
        statusLabel: '${orgCtrl?.checklists.length ?? 0} checklists',
        targetTab: LifeWorkspaceTab.checklists,
      ),
      _LifeDomainInfo(
        title: 'Shopping Lists',
        description: 'Quantities, units, and estimated totals separate from actual expenses.',
        icon: Icons.shopping_bag_outlined,
        statusLabel: '${orgCtrl?.shoppingLists.length ?? 0} lists',
        targetTab: LifeWorkspaceTab.shopping,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<Listenable> listenables = <Listenable>[
      ?widget.taskController,
      ?widget.billController,
      ?widget.reminderController,
      ?widget.lifeVaultController,
      ?widget.lifeOrganizationController,
    ];
    if (listenables.isEmpty) {
      return _buildBody(context, null, null, null, null, null);
    }
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (BuildContext context, _) => _buildBody(
        context,
        widget.taskController,
        widget.billController,
        widget.reminderController,
        widget.lifeVaultController,
        widget.lifeOrganizationController,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TaskController? ctrl,
    BillController? billCtrl,
    ReminderController? remCtrl,
    LifeVaultController? vaultCtrl,
    LifeOrganizationController? orgCtrl,
  ) {
    return KayaResponsiveScaffoldBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final LifeWorkspaceTab tab in LifeWorkspaceTab.values)
                ChoiceChip(
                  key: ValueKey<String>(tab.keyName),
                  label: Text(tab.label),
                  selected: _activeTab == tab,
                  onSelected: (_) => setState(() => _activeTab = tab),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          switch (_activeTab) {
            LifeWorkspaceTab.tasks =>
              ctrl != null
                  ? TasksWorkspaceSection(controller: ctrl)
                  : const KayaEmptyState(
                      icon: Icons.task_alt_outlined,
                      title: 'Tasks Not Connected',
                      description:
                          'Sign in to manage your tasks and due dates.',
                    ),
            LifeWorkspaceTab.billsAndReminders =>
              (billCtrl != null && remCtrl != null)
                  ? BillsRemindersWorkspaceSection(
                      billController: billCtrl,
                      reminderController: remCtrl,
                    )
                  : const KayaEmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'Bills & Reminders Not Connected',
                      description:
                          'Sign in to track unpaid bills and reminders.',
                    ),
            LifeWorkspaceTab.lifeVault =>
              vaultCtrl != null
                  ? LifeVaultWorkspaceSection(controller: vaultCtrl)
                  : const KayaEmptyState(
                      icon: Icons.lock_outline,
                      title: 'Life Vault Not Connected',
                      description: 'Sign in to organize important documents and belongings.',
                    ),
            LifeWorkspaceTab.routines =>
              orgCtrl != null
                  ? RoutinesWorkspaceSection(controller: orgCtrl)
                  : const KayaEmptyState(
                      icon: Icons.repeat_outlined,
                      title: 'Routines Not Connected',
                      description:
                          'Sign in to build daily routines and streaks.',
                    ),
            LifeWorkspaceTab.checklists =>
              orgCtrl != null
                  ? ChecklistsWorkspaceSection(controller: orgCtrl)
                  : const KayaEmptyState(
                      icon: Icons.checklist_outlined,
                      title: 'Checklists Not Connected',
                      description: 'Sign in to create reusable checklists.',
                    ),
            LifeWorkspaceTab.shopping =>
              orgCtrl != null
                  ? ShoppingWorkspaceSection(controller: orgCtrl)
                  : const KayaEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Shopping Lists Not Connected',
                      description:
                          'Sign in to manage shopping lists and estimates.',
                    ),
            LifeWorkspaceTab.overview => _buildOverviewDomains(
              context,
              _buildDomains(ctrl, billCtrl, remCtrl, vaultCtrl, orgCtrl),
            ),
          },
        ],
      ),
    );
  }

  Widget _buildOverviewDomains(
    BuildContext context,
    List<_LifeDomainInfo> domains,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const KayaSectionHeader(
          title: 'Life Domains',
          subtitle: 'Jump to any area of your personal workspace',
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = KayaResponsive.gridColumnsForWidth(
              constraints.maxWidth,
            );
            if (columns == 1) {
              return Column(
                children: <Widget>[
                  for (final _LifeDomainInfo domain in domains) ...<Widget>[
                    _LifeDomainCard(
                      domain: domain,
                      onTap: domain.targetTab != null
                          ? () => setState(() => _activeTab = domain.targetTab!)
                          : null,
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
                for (final _LifeDomainInfo domain in domains)
                  SizedBox(
                    width: itemWidth,
                    child: _LifeDomainCard(
                      domain: domain,
                      onTap: domain.targetTab != null
                          ? () => setState(() => _activeTab = domain.targetTab!)
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LifeDomainCard extends StatelessWidget {
  const _LifeDomainCard({required this.domain, this.onTap});

  final _LifeDomainInfo domain;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return KayaCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(domain.icon, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(domain.title, style: textTheme.titleMedium)),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(domain.description, style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            domain.statusLabel,
            style: textTheme.labelMedium?.copyWith(
              color: switch (domain.statusType) {
                KayaStatusType.critical => AppColors.error,
                KayaStatusType.warning => AppColors.warning,
                KayaStatusType.positive => AppColors.success,
                KayaStatusType.info => AppColors.info,
                KayaStatusType.neutral => AppColors.textSecondary,
              },
            ),
          ),
        ],
      ),
    );
  }
}
