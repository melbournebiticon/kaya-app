import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/bills/presentation/bill_card_tile.dart';
import 'package:kaya/features/bills/presentation/bill_form_dialog.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/reminders/presentation/reminder_card_tile.dart';
import 'package:kaya/features/reminders/presentation/reminder_form_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Unified Bills & Reminders management section displayed inside [LifeScreen].
class BillsRemindersWorkspaceSection extends StatefulWidget {
  const BillsRemindersWorkspaceSection({
    super.key,
    required this.billController,
    required this.reminderController,
  });

  final BillController billController;
  final ReminderController reminderController;

  @override
  State<BillsRemindersWorkspaceSection> createState() =>
      _BillsRemindersWorkspaceSectionState();
}

class _BillsRemindersWorkspaceSectionState
    extends State<BillsRemindersWorkspaceSection> {
  final TextEditingController _billSearchController = TextEditingController();

  @override
  void dispose() {
    _billSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.billController,
        widget.reminderController,
      ]),
      builder: (BuildContext context, _) => _buildContent(
        context,
        widget.billController,
        widget.reminderController,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    BillController billCtrl,
    ReminderController remCtrl,
  ) {
    final List<BillItem> visibleBills = billCtrl.filteredBills;
    final List<ReminderItem> visibleReminders = remCtrl.filteredReminders;
    final int unpaidCount = billCtrl.unpaidBills.length;
    final int overdueBillsCount = billCtrl.overdueBills.length;
    final int activeRemindersCount = remCtrl.activeReminders.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KayaSectionHeader(
          title: 'Bills & Reminders',
          subtitle: 'Unpaid bills reserve funds automatically in Safe to Spend',
          trailing: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              KayaButton(
                key: const ValueKey<String>('bills_add_button'),
                label: 'Add Bill',
                icon: Icons.receipt_long_outlined,
                onPressed: billCtrl.isMutating
                    ? null
                    : () => BillFormDialog.show(context, controller: billCtrl),
              ),
              KayaButton(
                key: const ValueKey<String>('reminders_add_button'),
                label: 'Add Reminder',
                icon: Icons.notifications_active_outlined,
                variant: KayaButtonVariant.secondary,
                onPressed: remCtrl.isMutating
                    ? null
                    : () =>
                          ReminderFormDialog.show(context, controller: remCtrl),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            Text(
              '$unpaidCount unpaid (${MoneyFormatter.formatMinorUnits(billCtrl.totalUnpaidInActiveCurrencyMinor, billCtrl.activeCurrency)})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: unpaidCount > 0
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
            ),
            if (overdueBillsCount > 0)
              Text(
                '$overdueBillsCount overdue bills',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.error),
              ),
            Text(
              '$activeRemindersCount active reminders',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.info),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (billCtrl.isLoading && billCtrl.allBills.isEmpty)
          const KayaLoadingState(
            title: 'Loading bills...',
            subtitle: 'Fetching upcoming and overdue payment obligations',
          )
        else if (billCtrl.hasLoadError)
          KayaErrorState(
            title: 'Unable to Load Bills',
            message:
                billCtrl.errorMessage ??
                'Could not fetch bills. Please try again.',
            onRetry: billCtrl.loadBills,
          )
        else ...<Widget>[
          Text('Bills', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final BillFilterView view in BillFilterView.values)
                ChoiceChip(
                  key: ValueKey<String>('bill_filter_${view.name}'),
                  label: Text(view.label),
                  selected: billCtrl.selectedView == view,
                  onSelected: (_) => billCtrl.setFilterView(view),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stackControls = constraints.maxWidth < 520;
              final Widget searchField = TextField(
                key: const ValueKey<String>('bills_search_field'),
                controller: _billSearchController,
                onChanged: billCtrl.setSearchQuery,
                decoration: InputDecoration(
                  labelText: 'Search bills',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _billSearchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _billSearchController.clear();
                            billCtrl.setSearchQuery('');
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
              );
              final Widget categoryDropdown =
                  DropdownButtonFormField<BillCategory?>(
                    key: const ValueKey<String>('bills_category_filter'),
                    initialValue: billCtrl.selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: <DropdownMenuItem<BillCategory?>>[
                      const DropdownMenuItem<BillCategory?>(
                        value: null,
                        child: Text(
                          'All categories',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final BillCategory cat in BillCategory.values)
                        DropdownMenuItem<BillCategory?>(
                          value: cat,
                          child: Text(
                            cat.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: billCtrl.setCategoryFilter,
                  );

              if (stackControls) {
                return Column(
                  children: <Widget>[
                    searchField,
                    const SizedBox(height: AppSpacing.sm),
                    categoryDropdown,
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 2, child: categoryDropdown),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          if (visibleBills.isEmpty)
            KayaEmptyState(
              icon: Icons.receipt_long_outlined,
              title: billCtrl.allBills.isEmpty
                  ? 'No Bills Recorded Yet'
                  : 'No Bills Match Filter',
              description: billCtrl.allBills.isEmpty
                  ? 'Track electricity, rent, subscriptions, or recurring bills so KAYA keeps your Safe to Spend honest.'
                  : 'No bills matched your selected view (${billCtrl.selectedView.label}).',
              actionLabel: billCtrl.allBills.isEmpty
                  ? 'Add Bill'
                  : 'Clear Filters',
              onAction: billCtrl.allBills.isEmpty
                  ? () => BillFormDialog.show(context, controller: billCtrl)
                  : () {
                      _billSearchController.clear();
                      billCtrl.clearFilters();
                    },
            )
          else
            Column(
              children: <Widget>[
                for (final BillItem item in visibleBills) ...<Widget>[
                  BillCardTile(
                    key: ValueKey<String>('bill_card_${item.id}'),
                    bill: item,
                    controller: billCtrl,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (remCtrl.isLoading && remCtrl.allReminders.isEmpty)
          const KayaLoadingState(
            title: 'Loading reminders...',
            subtitle: 'Checking upcoming dates and important alerts',
          )
        else if (remCtrl.hasLoadError)
          KayaErrorState(
            title: 'Unable to Load Reminders',
            message:
                remCtrl.errorMessage ??
                'Could not fetch reminders. Please try again.',
            onRetry: remCtrl.loadReminders,
          )
        else ...<Widget>[
          Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final ReminderFilterView view in ReminderFilterView.values)
                ChoiceChip(
                  key: ValueKey<String>('reminder_filter_${view.name}'),
                  label: Text(view.label),
                  selected: remCtrl.selectedView == view,
                  onSelected: (_) => remCtrl.setFilterView(view),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (visibleReminders.isEmpty)
            KayaEmptyState(
              icon: Icons.notifications_none_outlined,
              title: remCtrl.allReminders.isEmpty
                  ? 'No Reminders Scheduled Yet'
                  : 'No Reminders Match Filter',
              description: remCtrl.allReminders.isEmpty
                  ? 'Save important appointments, renewals, or due-date follow-ups.'
                  : 'No reminders matched your selected view (${remCtrl.selectedView.label}).',
              actionLabel: remCtrl.allReminders.isEmpty
                  ? 'Add Reminder'
                  : 'Show Active',
              onAction: remCtrl.allReminders.isEmpty
                  ? () => ReminderFormDialog.show(context, controller: remCtrl)
                  : remCtrl.clearFilters,
            )
          else
            Column(
              children: <Widget>[
                for (final ReminderItem item in visibleReminders) ...<Widget>[
                  ReminderCardTile(
                    key: ValueKey<String>('reminder_card_${item.id}'),
                    reminder: item,
                    controller: remCtrl,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
        ],
      ],
    );
  }
}
