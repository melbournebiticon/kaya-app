import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/bills/domain/bill_repository.dart';
import 'package:kaya/features/bills/presentation/bill_form_dialog.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:material_ui/material_ui.dart';

/// Displays an individual [BillItem] with confirmed Paid/Unpaid safeguard,
/// Undo SnackBar, Edit, and Confirmed Delete controls.
class BillCardTile extends StatelessWidget {
  const BillCardTile({super.key, required this.bill, required this.controller});

  final BillItem bill;
  final BillController controller;

  Future<void> _handleDelete(BuildContext context) async {
    final String formatted = MoneyFormatter.formatMinorUnits(
      bill.amountMinor,
      bill.currency,
    );
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Delete Bill?',
      message:
          'Are you sure you want to delete "${bill.title}" ($formatted)? Unpaid obligations and Safe to Spend will be updated.',
      confirmLabel: 'Delete Bill',
    );
    if (confirmed) {
      await controller.deleteBill(bill.id);
    }
  }

  Future<void> _handleTogglePaid(
    BuildContext context,
    BillDueBucket bucket,
  ) async {
    final bool nextPaid = !bill.isPaid;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final String formatted = MoneyFormatter.formatMinorUnits(
      bill.amountMinor,
      bill.currency,
    );

    final String title;
    final String message;
    final String confirmLabel;

    if (nextPaid && bucket == BillDueBucket.upcoming) {
      title = 'Mark Upcoming Bill as Paid Early?';
      message =
          '"${bill.title}" ($formatted) is due on ${bill.dueDate.formatReadable()} (${bill.dueStatusLabel(controller.referenceToday)}). Confirm marking it paid early?';
      confirmLabel = 'Mark Paid Early';
    } else if (nextPaid) {
      title = 'Mark Bill as Paid?';
      message =
          'Mark "${bill.title}" ($formatted) as paid and exclude it from unpaid obligations?';
      confirmLabel = 'Mark Paid';
    } else {
      title = 'Mark Bill as Unpaid?';
      message =
          'Return "${bill.title}" ($formatted) to unpaid obligations? It will count against Safe to Spend again.';
      confirmLabel = 'Mark Unpaid';
    }

    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      isDestructive: false,
    );
    if (!confirmed) {
      return;
    }

    final BillStatusUpdateResult? result = await controller.setBillPaid(
      billId: bill.id,
      isPaid: nextPaid,
    );
    if (result != null && messenger != null) {
      final String nextCycleNote = result.spawnedNextBill != null
          ? ' Next cycle scheduled for ${result.spawnedNextBill!.dueDate.formatReadable()}.'
          : '';
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nextPaid
                ? 'Marked "${bill.title}" as paid.$nextCycleNote'
                : 'Reopened "${bill.title}" as unpaid.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primary,
            onPressed: () {
              controller.setBillPaid(billId: bill.id, isPaid: !nextPaid);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final KayaDateOnly today = controller.referenceToday;
    final BillDueBucket bucket = bill.dueBucket(today);

    final Color dueColor = bill.isPaid
        ? AppColors.success
        : switch (bucket) {
            BillDueBucket.overdue => AppColors.error,
            BillDueBucket.today => AppColors.warning,
            BillDueBucket.upcoming => AppColors.info,
          };

    final String formattedAmount = MoneyFormatter.formatMinorUnits(
      bill.amountMinor,
      bill.currency,
    );

    return KayaCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      highlighted: !bill.isPaid && bucket == BillDueBucket.overdue,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            key: ValueKey<String>('bill_toggle_paid_${bill.id}'),
            tooltip: bill.isPaid ? 'Mark unpaid' : 'Mark paid',
            onPressed: controller.isMutating
                ? null
                : () => _handleTogglePaid(context, bucket),
            icon: Icon(
              bill.isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
              color: bill.isPaid ? AppColors.success : AppColors.primary,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          bill.title,
                          style: textTheme.titleMedium?.copyWith(
                            decoration: bill.isPaid
                                ? TextDecoration.lineThrough
                                : null,
                            color: bill.isPaid
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        formattedAmount,
                        style: textTheme.titleMedium?.copyWith(
                          color: bill.isPaid
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            bill.isPaid
                                ? Icons.verified_outlined
                                : (bucket == BillDueBucket.overdue
                                      ? Icons.warning_amber_outlined
                                      : Icons.receipt_long_outlined),
                            size: 14,
                            color: dueColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            bill.dueStatusLabel(today),
                            style: textTheme.bodySmall?.copyWith(
                              color: dueColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '• ${bill.category.label}${bill.recurrence == BillRecurrence.oneTime ? '' : ' • ${bill.recurrence.label}'}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (bill.notes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(bill.notes, style: textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey<String>('bill_edit_${bill.id}'),
            tooltip: 'Edit bill',
            icon: const Icon(
              Icons.edit_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            onPressed: controller.isMutating
                ? null
                : () => BillFormDialog.show(
                    context,
                    controller: controller,
                    existingBill: bill,
                  ),
          ),
          IconButton(
            key: ValueKey<String>('bill_delete_${bill.id}'),
            tooltip: 'Delete bill',
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
