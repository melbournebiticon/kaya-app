import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/domain/belonging_item.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/life_vault/presentation/belonging_form_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Displays an individual [BelongingItem] with custody status, confirmed
/// return toggle (with Undo SnackBar), Edit, and Confirmed Delete controls.
class BelongingCardTile extends StatelessWidget {
  const BelongingCardTile({
    super.key,
    required this.belonging,
    required this.controller,
  });

  final BelongingItem belonging;
  final LifeVaultController controller;

  Future<void> _handleDelete(BuildContext context) async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Delete Belonging Record?',
      message:
          'Are you sure you want to remove "${belonging.title}" from your Life Vault? This action cannot be undone.',
      confirmLabel: 'Delete Belonging',
    );
    if (confirmed) {
      await controller.deleteBelonging(belonging.id);
    }
  }

  Future<void> _handleToggleReturned(BuildContext context) async {
    final bool nextReturned = !belonging.isReturned;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );

    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: nextReturned ? 'Mark Item as Returned?' : 'Reopen Loan Tracking?',
      message: nextReturned
          ? 'Confirm that "${belonging.title}" has been returned?'
          : 'Mark "${belonging.title}" as still out / unreturned?',
      confirmLabel: nextReturned ? 'Mark Returned' : 'Reopen Loan',
      isDestructive: false,
    );
    if (!confirmed) {
      return;
    }

    final bool updated = await controller.setBelongingReturned(
      belongingId: belonging.id,
      isReturned: nextReturned,
    );
    if (updated && messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nextReturned
                ? 'Marked "${belonging.title}" as returned.'
                : 'Reopened return tracking for "${belonging.title}".',
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primary,
            onPressed: () {
              controller.setBelongingReturned(
                belongingId: belonging.id,
                isReturned: !nextReturned,
              );
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
    final bool isReturnOverdue = belonging.isReturnOverdue(today);

    final Color custodyColor;
    if (belonging.custodyType == BelongingCustodyType.owned) {
      custodyColor = AppColors.textSecondary;
    } else if (belonging.isReturned) {
      custodyColor = AppColors.success;
    } else if (isReturnOverdue) {
      custodyColor = AppColors.error;
    } else {
      custodyColor = AppColors.warning;
    }

    return KayaCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      highlighted: isReturnOverdue,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (belonging.isLoanItem)
            IconButton(
              key: ValueKey<String>(
                'vault_blg_toggle_returned_${belonging.id}',
              ),
              tooltip: belonging.isReturned ? 'Reopen loan' : 'Mark returned',
              onPressed: controller.isMutating
                  ? null
                  : () => _handleToggleReturned(context),
              icon: Icon(
                belonging.isReturned
                    ? Icons.check_circle
                    : Icons.swap_horiz_rounded,
                color: belonging.isReturned
                    ? AppColors.success
                    : AppColors.warning,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.secondary,
                  size: 18,
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(belonging.title, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${belonging.category.label} • ${belonging.storageLocation}',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        belonging.isReturned
                            ? Icons.assignment_turned_in_outlined
                            : (belonging.isLoanItem
                                  ? Icons.people_outline
                                  : Icons.home_outlined),
                        size: 14,
                        color: custodyColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          belonging.custodyStatusLabel(today),
                          style: textTheme.bodySmall?.copyWith(
                            color: custodyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (belonging.notes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(belonging.notes, style: textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey<String>('vault_blg_edit_${belonging.id}'),
            tooltip: 'Edit belonging',
            icon: const Icon(
              Icons.edit_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            onPressed: controller.isMutating
                ? null
                : () => BelongingFormDialog.show(
                    context,
                    controller: controller,
                    existingBelonging: belonging,
                  ),
          ),
          IconButton(
            key: ValueKey<String>('vault_blg_delete_${belonging.id}'),
            tooltip: 'Delete belonging',
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
