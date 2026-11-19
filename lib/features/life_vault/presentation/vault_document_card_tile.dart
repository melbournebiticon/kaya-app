import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:kaya/features/life_vault/presentation/vault_document_form_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Displays an important [VaultDocument] with expiration status, physical
/// location, Edit, and Confirmed Delete controls.
class VaultDocumentCardTile extends StatelessWidget {
  const VaultDocumentCardTile({
    super.key,
    required this.document,
    required this.controller,
  });

  final VaultDocument document;
  final LifeVaultController controller;

  Future<void> _handleDelete(BuildContext context) async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Delete Document Record?',
      message:
          'Are you sure you want to remove "${document.title}" from your Life Vault? This action cannot be undone.',
      confirmLabel: 'Delete Document',
    );
    if (confirmed) {
      await controller.deleteDocument(document.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final KayaDateOnly today = controller.referenceToday;
    final DocumentExpirationStatus status = document.expirationStatus(today);

    final Color statusColor = switch (status) {
      DocumentExpirationStatus.expired => AppColors.error,
      DocumentExpirationStatus.expiringSoon => AppColors.warning,
      DocumentExpirationStatus.valid => AppColors.success,
      DocumentExpirationStatus.noExpiration => AppColors.textMuted,
    };

    return KayaCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      highlighted:
          status == DocumentExpirationStatus.expired ||
          status == DocumentExpirationStatus.expiringSoon,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(document.title, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${document.category.label} • ${document.physicalLocation}',
                  style: textTheme.bodySmall,
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
                          status == DocumentExpirationStatus.expired
                              ? Icons.error_outline
                              : (status == DocumentExpirationStatus.expiringSoon
                                    ? Icons.warning_amber_outlined
                                    : Icons.verified_user_outlined),
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          document.expirationStatusLabel(today),
                          style: textTheme.bodySmall?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    if (document.issueDate != null)
                      Text(
                        '• Issued ${document.issueDate!.formatReadable()}',
                        style: textTheme.bodySmall,
                      ),
                  ],
                ),
                if (document.notes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(document.notes, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
          IconButton(
            key: ValueKey<String>('vault_doc_edit_${document.id}'),
            tooltip: 'Edit document',
            icon: const Icon(
              Icons.edit_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            onPressed: controller.isMutating
                ? null
                : () => VaultDocumentFormDialog.show(
                    context,
                    controller: controller,
                    existingDocument: document,
                  ),
          ),
          IconButton(
            key: ValueKey<String>('vault_doc_delete_${document.id}'),
            tooltip: 'Delete document',
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
