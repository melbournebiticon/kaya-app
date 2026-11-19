import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:kaya/features/money/presentation/transaction_form_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Displays an actual income or expense [MoneyTransaction] with edit and
/// confirmed delete actions.
class TransactionCardTile extends StatelessWidget {
  const TransactionCardTile({
    super.key,
    required this.transaction,
    required this.controller,
  });

  final MoneyTransaction transaction;
  final MoneyController controller;

  Future<void> _handleDelete(BuildContext context) async {
    final String formatted = MoneyFormatter.formatMinorUnits(
      transaction.amountMinor,
      transaction.currency,
    );
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Delete Transaction?',
      message:
          'Are you sure you want to delete "${transaction.title}" ($formatted)? Your Available Balance and Safe to Spend will be recalculated.',
      confirmLabel: 'Delete Transaction',
    );
    if (confirmed) {
      await controller.deleteTransaction(transaction.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isIncome = transaction.type == TransactionType.income;
    final String signedAmount = MoneyFormatter.formatMinorUnits(
      isIncome ? transaction.amountMinor : -transaction.amountMinor,
      transaction.currency,
      includePlusSign: isIncome,
    );

    return KayaCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isIncome
                  ? AppColors.successSurface
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isIncome ? AppColors.success : AppColors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        transaction.title,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      signedAmount,
                      style: textTheme.titleMedium?.copyWith(
                        color: isIncome
                            ? AppColors.success
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${transaction.category.label} • ${transaction.transactionDate.formatReadable()}',
                  style: textTheme.bodySmall,
                ),
                if (transaction.notes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(transaction.notes, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
          IconButton(
            key: ValueKey<String>('tx_edit_${transaction.id}'),
            tooltip: 'Edit transaction',
            icon: const Icon(
              Icons.edit_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            onPressed: controller.isMutating
                ? null
                : () => TransactionFormDialog.show(
                    context,
                    controller: controller,
                    existingTransaction: transaction,
                  ),
          ),
          IconButton(
            key: ValueKey<String>('tx_delete_${transaction.id}'),
            tooltip: 'Delete transaction',
            icon: const Icon(
              Icons.delete_outline,
              size: 19,
              color: AppColors.textMuted,
            ),
            onPressed: controller.isMutating
                ? null
                : () => _handleDelete(context),
          ),
        ],
      ),
    );
  }
}
