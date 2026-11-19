import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/domain/belonging_item.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:kaya/features/life_vault/presentation/belonging_card_tile.dart';
import 'package:kaya/features/life_vault/presentation/belonging_form_dialog.dart';
import 'package:kaya/features/life_vault/presentation/vault_document_card_tile.dart';
import 'package:kaya/features/life_vault/presentation/vault_document_form_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Unified Life Vault section for important documents and personal belongings,
/// rendered inside [LifeScreen].
class LifeVaultWorkspaceSection extends StatefulWidget {
  const LifeVaultWorkspaceSection({super.key, required this.controller});

  final LifeVaultController controller;

  @override
  State<LifeVaultWorkspaceSection> createState() =>
      _LifeVaultWorkspaceSectionState();
}

class _LifeVaultWorkspaceSectionState extends State<LifeVaultWorkspaceSection> {
  final TextEditingController _docSearchController = TextEditingController();
  final TextEditingController _belongingSearchController =
      TextEditingController();

  @override
  void dispose() {
    _docSearchController.dispose();
    _belongingSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) =>
          _buildContent(context, widget.controller),
    );
  }

  Widget _buildContent(BuildContext context, LifeVaultController ctrl) {
    final List<VaultDocument> visibleDocs = ctrl.filteredDocuments;
    final List<BelongingItem> visibleBelongings = ctrl.filteredBelongings;
    final int expiringSoonCount = ctrl.expiringSoonDocuments.length;
    final int expiredCount = ctrl.expiredDocuments.length;
    final int activeLoansCount = ctrl.activeLoans.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KayaSectionHeader(
          title: 'Life Vault',
          subtitle:
              'Track important documents, expiration dates, and personal gear',
          trailing: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              KayaButton(
                key: const ValueKey<String>('vault_add_document_button'),
                label: 'Add Document',
                icon: Icons.badge_outlined,
                onPressed: ctrl.isMutating
                    ? null
                    : () => VaultDocumentFormDialog.show(
                        context,
                        controller: ctrl,
                      ),
              ),
              KayaButton(
                key: const ValueKey<String>('vault_add_belonging_button'),
                label: 'Add Belonging',
                icon: Icons.inventory_2_outlined,
                variant: KayaButtonVariant.secondary,
                onPressed: ctrl.isMutating
                    ? null
                    : () => BelongingFormDialog.show(context, controller: ctrl),
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
              '${ctrl.allDocuments.length} documents',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.info),
            ),
            if (expiredCount > 0)
              Text(
                '$expiredCount expired',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.error),
              ),
            if (expiringSoonCount > 0)
              Text(
                '$expiringSoonCount expiring soon',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.warning),
              ),
            Text(
              '${ctrl.allBelongings.length} belongings ($activeLoansCount on loan)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: activeLoansCount > 0
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (ctrl.isLoading &&
            ctrl.allDocuments.isEmpty &&
            ctrl.allBelongings.isEmpty)
          const KayaLoadingState(
            title: 'Loading Life Vault...',
            subtitle: 'Fetching documents and personal belongings safely',
          )
        else if (ctrl.hasLoadError)
          KayaErrorState(
            title: 'Unable to Load Life Vault',
            message:
                ctrl.errorMessage ??
                'Could not fetch Life Vault items. Please try again.',
            onRetry: ctrl.loadVault,
          )
        else ...<Widget>[
          Text(
            'Important Documents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final DocumentFilterView view in DocumentFilterView.values)
                ChoiceChip(
                  key: ValueKey<String>('vault_doc_filter_${view.name}'),
                  label: Text(view.label),
                  selected: ctrl.docFilter == view,
                  onSelected: (_) => ctrl.setDocFilter(view),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stack = constraints.maxWidth < 520;
              final Widget searchField = TextField(
                key: const ValueKey<String>('vault_doc_search_field'),
                controller: _docSearchController,
                onChanged: ctrl.setDocSearchQuery,
                decoration: InputDecoration(
                  labelText: 'Search documents or location',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _docSearchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _docSearchController.clear();
                            ctrl.setDocSearchQuery('');
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
              );
              final Widget
              categoryDropdown = DropdownButtonFormField<DocumentCategory?>(
                key: const ValueKey<String>('vault_doc_category_filter'),
                initialValue: ctrl.docCategoryFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: <DropdownMenuItem<DocumentCategory?>>[
                  const DropdownMenuItem<DocumentCategory?>(
                    value: null,
                    child: Text(
                      'All categories',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final DocumentCategory cat in DocumentCategory.values)
                    DropdownMenuItem<DocumentCategory?>(
                      value: cat,
                      child: Text(cat.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: ctrl.setDocCategoryFilter,
              );

              if (stack) {
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
          if (visibleDocs.isEmpty)
            KayaEmptyState(
              icon: Icons.badge_outlined,
              title: ctrl.allDocuments.isEmpty
                  ? 'No Documents in Life Vault Yet'
                  : 'No Documents Match Filter',
              description: ctrl.allDocuments.isEmpty
                  ? 'Store passport, IDs, insurance policies, and physical folder locations with automatic expiration alerts.'
                  : 'No documents matched your current search or expiration filter.',
              actionLabel: ctrl.allDocuments.isEmpty
                  ? 'Add Document'
                  : 'Clear Filters',
              onAction: ctrl.allDocuments.isEmpty
                  ? () =>
                        VaultDocumentFormDialog.show(context, controller: ctrl)
                  : () {
                      _docSearchController.clear();
                      ctrl.clearDocFilters();
                    },
            )
          else
            Column(
              children: <Widget>[
                for (final VaultDocument doc in visibleDocs) ...<Widget>[
                  VaultDocumentCardTile(
                    key: ValueKey<String>('vault_doc_card_${doc.id}'),
                    document: doc,
                    controller: ctrl,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Personal Belongings & Borrowed/Lent Items',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final BelongingFilterView view in BelongingFilterView.values)
                ChoiceChip(
                  key: ValueKey<String>('vault_blg_filter_${view.name}'),
                  label: Text(view.label),
                  selected: ctrl.belongingFilter == view,
                  onSelected: (_) => ctrl.setBelongingFilter(view),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stack = constraints.maxWidth < 520;
              final Widget searchField = TextField(
                key: const ValueKey<String>('vault_blg_search_field'),
                controller: _belongingSearchController,
                onChanged: ctrl.setBelongingSearchQuery,
                decoration: InputDecoration(
                  labelText: 'Search items, person, or storage spot',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _belongingSearchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _belongingSearchController.clear();
                            ctrl.setBelongingSearchQuery('');
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
              );
              final Widget
              categoryDropdown = DropdownButtonFormField<BelongingCategory?>(
                key: const ValueKey<String>('vault_blg_category_filter'),
                initialValue: ctrl.belongingCategoryFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: <DropdownMenuItem<BelongingCategory?>>[
                  const DropdownMenuItem<BelongingCategory?>(
                    value: null,
                    child: Text(
                      'All categories',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final BelongingCategory cat in BelongingCategory.values)
                    DropdownMenuItem<BelongingCategory?>(
                      value: cat,
                      child: Text(cat.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: ctrl.setBelongingCategoryFilter,
              );

              if (stack) {
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
          if (visibleBelongings.isEmpty)
            KayaEmptyState(
              icon: Icons.inventory_2_outlined,
              title: ctrl.allBelongings.isEmpty
                  ? 'No Personal Belongings Tracked Yet'
                  : 'No Belongings Match Filter',
              description: ctrl.allBelongings.isEmpty
                  ? 'Track where important gear lives or who currently holds your lent or borrowed items.'
                  : 'No belongings matched your active custody or category filters.',
              actionLabel: ctrl.allBelongings.isEmpty
                  ? 'Add Belonging'
                  : 'Clear Filters',
              onAction: ctrl.allBelongings.isEmpty
                  ? () => BelongingFormDialog.show(context, controller: ctrl)
                  : () {
                      _belongingSearchController.clear();
                      ctrl.clearBelongingFilters();
                    },
            )
          else
            Column(
              children: <Widget>[
                for (final BelongingItem item in visibleBelongings) ...<Widget>[
                  BelongingCardTile(
                    key: ValueKey<String>('vault_blg_card_${item.id}'),
                    belonging: item,
                    controller: ctrl,
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
