import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/responsive_layout.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';
import 'package:kaya/features/money/presentation/can_i_buy_this_card.dart';
import 'package:kaya/features/money/presentation/monthly_budget_dialog.dart';
import 'package:kaya/features/money/presentation/transaction_card_tile.dart';
import 'package:kaya/features/money/presentation/transaction_form_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Money module screen (Phase 4 — Money Management).
///
/// Consumes [MoneyController.currentOverview] computed exclusively by
/// [SafeToSpendCalculator]. Never duplicates financial formulas or mixes
/// estimates with actual transactions.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key, this.moneyController});

  final MoneyController? moneyController;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MoneyController? ctrl = widget.moneyController;
    if (ctrl == null) {
      return _buildReadOnlyEmptyShell(context);
    }

    return ListenableBuilder(
      listenable: ctrl,
      builder: (BuildContext context, _) => _buildWorkspace(context, ctrl),
    );
  }

  Widget _buildReadOnlyEmptyShell(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return KayaResponsiveScaffoldBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          KayaCard(
            padding: AppSpacing.cardPaddingLarge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Safe to Spend', style: textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Sign in to start tracking income, expenses, and monthly budgets.',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace(BuildContext context, MoneyController ctrl) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final FinancialOverviewSummary overview = ctrl.currentOverview;
    final SupportedCurrency currency = overview.currency;
    final List<MoneyTransaction> visibleTransactions =
        ctrl.filteredTransactions;

    if (ctrl.isLoading && !overview.hasAnyActivity) {
      return const KayaResponsiveScaffoldBody(
        child: KayaLoadingState(
          title: 'Loading financial overview...',
          subtitle: 'Synchronizing verified transactions and monthly budgets',
        ),
      );
    }

    if (ctrl.hasLoadError) {
      return KayaResponsiveScaffoldBody(
        child: KayaErrorState(
          title: 'Unable to Load Financial Data',
          message:
              ctrl.errorMessage ??
              'Could not load your money workspace. Please try again.',
          onRetry: ctrl.loadMoneyData,
        ),
      );
    }

    final KayaStatusType healthBadgeType = switch (overview.health) {
      SafeToSpendHealth.healthy => KayaStatusType.positive,
      SafeToSpendHealth.caution => KayaStatusType.warning,
      SafeToSpendHealth.critical => KayaStatusType.critical,
      SafeToSpendHealth.unconfigured => KayaStatusType.neutral,
    };

    return KayaResponsiveScaffoldBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          KayaCard(
            padding: AppSpacing.cardPaddingLarge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      '${ctrl.selectedPeriodLabel} • ${currency.code}',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (overview.hasAnyActivity)
                      KayaStatusBadge(
                        label: overview.health.label,
                        type: healthBadgeType,
                        customIcon:
                            overview.health == SafeToSpendHealth.critical
                            ? Icons.warning_amber_outlined
                            : Icons.verified_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Safe to Spend', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                if (!overview.hasAnyActivity)
                  Text(
                    'Add income, expenses, or a monthly budget for ${ctrl.selectedPeriodLabel} to calculate what is safe to spend.',
                    style: textTheme.bodyMedium,
                  )
                else ...<Widget>[
                  Text(
                    MoneyFormatter.formatMinorUnits(
                      overview.safeToSpendMinor,
                      currency,
                    ),
                    key: const ValueKey<String>('money_safe_to_spend_value'),
                    style: textTheme.displaySmall?.copyWith(
                      color: overview.safeToSpendMinor <= 0
                          ? AppColors.error
                          : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (overview.deficitMinor > 0) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Over limit by ${MoneyFormatter.formatMinorUnits(overview.deficitMinor, currency)}. Hold off on extra spending until cash flow recovers.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final int columns = constraints.maxWidth >= 680
                        ? 3
                        : (constraints.maxWidth >= 420 ? 2 : 1);
                    const double spacing = AppSpacing.sm;
                    final double itemWidth = columns == 1
                        ? constraints.maxWidth
                        : (constraints.maxWidth - (spacing * (columns - 1))) /
                              columns;

                    final List<Widget> statBoxes = <Widget>[
                      _FinancialStatBox(
                        key: const ValueKey<String>(
                          'money_available_balance_box',
                        ),
                        label: 'Available Balance',
                        value: MoneyFormatter.formatMinorUnits(
                          overview.availableBalanceMinor,
                          currency,
                        ),
                        accentColor: overview.availableBalanceMinor < 0
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                      _FinancialStatBox(
                        key: const ValueKey<String>('money_total_income_box'),
                        label: 'Total Income',
                        value: MoneyFormatter.formatMinorUnits(
                          overview.totalIncomeMinor,
                          currency,
                        ),
                        accentColor: AppColors.success,
                      ),
                      _FinancialStatBox(
                        key: const ValueKey<String>('money_total_expenses_box'),
                        label: 'Total Expenses',
                        value: MoneyFormatter.formatMinorUnits(
                          overview.totalExpensesMinor,
                          currency,
                        ),
                        accentColor: AppColors.warning,
                      ),
                    ];

                    if (columns == 1) {
                      return Column(
                        children: <Widget>[
                          for (final Widget box in statBoxes) ...<Widget>[
                            box,
                            const SizedBox(height: AppSpacing.xs),
                          ],
                        ],
                      );
                    }

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: <Widget>[
                        for (final Widget box in statBoxes)
                          SizedBox(width: itemWidth, child: box),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _BudgetProgressStrip(overview: overview),
                if (overview.unpaidObligationsMinor > 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  KayaStatusBadge(
                    key: const ValueKey<String>(
                      'money_unpaid_bills_reserved_badge',
                    ),
                    label:
                        'Unpaid Bills Reserved: ${MoneyFormatter.formatMinorUnits(overview.unpaidObligationsMinor, currency)}',
                    type: KayaStatusType.warning,
                    customIcon: Icons.receipt_long_outlined,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    KayaButton(
                      key: const ValueKey<String>('money_add_income_button'),
                      label: 'Add Income',
                      icon: Icons.add_circle_outline,
                      onPressed: ctrl.isMutating
                          ? null
                          : () => TransactionFormDialog.show(
                              context,
                              controller: ctrl,
                              initialType: TransactionType.income,
                            ),
                    ),
                    KayaButton(
                      key: const ValueKey<String>('money_add_expense_button'),
                      label: 'Add Expense',
                      icon: Icons.remove_circle_outline,
                      variant: KayaButtonVariant.secondary,
                      onPressed: ctrl.isMutating
                          ? null
                          : () => TransactionFormDialog.show(
                              context,
                              controller: ctrl,
                              initialType: TransactionType.expense,
                            ),
                    ),
                    KayaButton(
                      key: const ValueKey<String>('money_set_budget_button'),
                      label: overview.hasBudget
                          ? 'Update Budget'
                          : 'Set Monthly Budget',
                      icon: Icons.pie_chart_outline,
                      variant: KayaButtonVariant.outline,
                      onPressed: ctrl.isMutating
                          ? null
                          : () => MonthlyBudgetDialog.show(
                              context,
                              controller: ctrl,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CanIBuyThisCard(controller: ctrl),
          if (overview.categoryBreakdowns.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const KayaSectionHeader(
              title: 'Spending by Category',
              subtitle: 'Actual expenses recorded this month',
            ),
            const SizedBox(height: AppSpacing.sm),
            KayaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final CategorySpendBreakdown item
                      in overview.categoryBreakdowns) ...<Widget>[
                    _CategoryBreakdownRow(item: item, currency: currency),
                    if (item != overview.categoryBreakdowns.last)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          KayaSectionHeader(
            title: 'Transactions (${visibleTransactions.length})',
            subtitle: 'Verified income and expense records (no estimates)',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final TransactionFilterType filter
                  in TransactionFilterType.values)
                ChoiceChip(
                  key: ValueKey<String>('money_filter_${filter.name}'),
                  label: Text(filter.label),
                  selected: ctrl.selectedFilter == filter,
                  onSelected: (_) => ctrl.setFilterType(filter),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stackControls = constraints.maxWidth < 520;
              final Widget searchField = TextField(
                key: const ValueKey<String>('money_search_field'),
                controller: _searchController,
                onChanged: ctrl.setSearchQuery,
                decoration: InputDecoration(
                  labelText: 'Search transactions',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            ctrl.setSearchQuery('');
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
              );
              final Widget categoryDropdown =
                  DropdownButtonFormField<MoneyCategory?>(
                    key: const ValueKey<String>('money_category_filter'),
                    initialValue: ctrl.selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: <DropdownMenuItem<MoneyCategory?>>[
                      const DropdownMenuItem<MoneyCategory?>(
                        value: null,
                        child: Text(
                          'All categories',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final MoneyCategory cat in MoneyCategory.values)
                        DropdownMenuItem<MoneyCategory?>(
                          value: cat,
                          child: Text(
                            cat.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: ctrl.setCategoryFilter,
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
          const SizedBox(height: AppSpacing.md),
          if (visibleTransactions.isEmpty)
            KayaEmptyState(
              icon: Icons.receipt_long_outlined,
              title: overview.transactionCount == 0
                  ? 'No Financial Records Yet'
                  : 'No Matching Transactions',
              description: overview.transactionCount == 0
                  ? 'KAYA never displays fabricated numbers. Your real income, expenses, and budget breakdowns will appear here once added.'
                  : 'No transactions matched your active filters for ${ctrl.selectedPeriodLabel}.',
              actionLabel: overview.transactionCount == 0
                  ? 'Add Income'
                  : 'Clear Filters',
              onAction: overview.transactionCount == 0
                  ? () => TransactionFormDialog.show(
                      context,
                      controller: ctrl,
                      initialType: TransactionType.income,
                    )
                  : () {
                      _searchController.clear();
                      ctrl.clearFilters();
                    },
            )
          else
            Column(
              children: <Widget>[
                for (final MoneyTransaction tx
                    in visibleTransactions) ...<Widget>[
                  TransactionCardTile(
                    key: ValueKey<String>('money_tx_card_${tx.id}'),
                    transaction: tx,
                    controller: ctrl,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _FinancialStatBox extends StatelessWidget {
  const _FinancialStatBox({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetProgressStrip extends StatelessWidget {
  const _BudgetProgressStrip({required this.overview});

  final FinancialOverviewSummary overview;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final SupportedCurrency currency = overview.currency;

    if (!overview.hasBudget) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.pie_chart_outline,
              size: 18,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Monthly budget not configured yet — Safe to Spend currently reflects Available Balance.',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final int limitMinor = overview.monthlyBudgetLimitMinor!;
    final int remainingMinor = overview.remainingBudgetMinor!;
    final double rawRatio = overview.budgetUtilizationRatio ?? 0.0;
    final double clampedProgress = rawRatio.clamp(0.0, 1.0);
    final int percent = (rawRatio * 100).round();

    final Color barColor = remainingMinor < 0
        ? AppColors.error
        : (rawRatio >= 0.80 ? AppColors.warning : AppColors.primary);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Monthly Budget: ${MoneyFormatter.formatMinorUnits(limitMinor, currency)} ($percent% used)',
                style: textTheme.labelMedium,
              ),
              Text(
                remainingMinor >= 0
                    ? '${MoneyFormatter.formatMinorUnits(remainingMinor, currency)} remaining'
                    : '${MoneyFormatter.formatMinorUnits(-remainingMinor, currency)} over budget',
                style: textTheme.labelMedium?.copyWith(color: barColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownRow extends StatelessWidget {
  const _CategoryBreakdownRow({required this.item, required this.currency});

  final CategorySpendBreakdown item;
  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int pct = (item.shareOfExpensesRatio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                item.category.label,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${MoneyFormatter.formatMinorUnits(item.spentMinor, currency)} ($pct%)',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: LinearProgressIndicator(
            value: item.shareOfExpensesRatio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.background,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
