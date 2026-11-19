import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/validation/life_organization_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/checklists/domain/smart_checklist.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Smart Checklists workspace inside [LifeScreen] (Phase 7).
class ChecklistsWorkspaceSection extends StatefulWidget {
  const ChecklistsWorkspaceSection({super.key, required this.controller});

  final LifeOrganizationController controller;

  @override
  State<ChecklistsWorkspaceSection> createState() =>
      _ChecklistsWorkspaceSectionState();
}

class _ChecklistsWorkspaceSectionState
    extends State<ChecklistsWorkspaceSection> {
  final Map<String, TextEditingController> _itemControllers =
      <String, TextEditingController>{};

  @override
  void dispose() {
    for (final TextEditingController ctrl in _itemControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TextEditingController _itemControllerFor(String checklistId) {
    return _itemControllers.putIfAbsent(checklistId, TextEditingController.new);
  }

  Future<void> _showCreateChecklistDialog() async {
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => const _CreateChecklistDialog(),
    );

    if (title != null) {
      await widget.controller.createChecklist(title: title);
    }
  }

  Future<void> _handleAddItem(String checklistId) async {
    final TextEditingController ctrl = _itemControllerFor(checklistId);
    final String? validationError = LifeOrganizationValidators.validateTitle(
      ctrl.text,
      fieldName: 'Item name',
    );
    if (validationError != null) {
      return;
    }
    final bool ok = await widget.controller.addChecklistItem(
      checklistId: checklistId,
      title: ctrl.text,
    );
    if (ok && mounted) {
      ctrl.clear();
    }
  }

  Future<void> _handleResetChecklist(SmartChecklist checklist) async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Reset Checked Items?',
      message:
          'Uncheck all ${checklist.completedCount} completed item(s) in "${checklist.title}" so you can reuse this list?',
      confirmLabel: 'Reset Items',
      isDestructive: false,
    );
    if (confirmed) {
      await widget.controller.resetChecklistCompletedItems(checklist.id);
    }
  }

  Future<void> _handleDeleteChecklist(SmartChecklist checklist) async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Delete Checklist?',
      message:
          'Are you sure you want to delete "${checklist.title}" and its items?',
      confirmLabel: 'Delete Checklist',
    );
    if (confirmed) {
      await widget.controller.deleteChecklist(checklist.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) =>
          _buildContent(context, widget.controller),
    );
  }

  Widget _buildContent(BuildContext context, LifeOrganizationController ctrl) {
    final List<SmartChecklist> checklists = ctrl.checklists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KayaSectionHeader(
          title: 'Smart Checklists',
          subtitle: 'Reusable lists for packing, errands, and prep work',
          trailing: KayaButton(
            key: const ValueKey<String>('checklists_create_button'),
            label: 'New Checklist',
            icon: Icons.add,
            onPressed: ctrl.isMutating ? null : _showCreateChecklistDialog,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (ctrl.isLoading && checklists.isEmpty)
          const KayaLoadingState(
            title: 'Loading checklists...',
            subtitle: 'Preparing your saved checklists.',
          )
        else if (ctrl.hasLoadError)
          KayaErrorState(
            title: 'Unable to Load Checklists',
            message:
                ctrl.errorMessage ??
                'Could not fetch checklists. Please try again.',
            onRetry: ctrl.loadAll,
          )
        else if (checklists.isEmpty)
          KayaEmptyState(
            icon: Icons.checklist_outlined,
            title: 'No Checklists Yet',
            description: 'Create reusable checklists for travel packing, weekly chores, or project launches and reset them anytime.',
            actionLabel: 'Create Checklist',
            onAction: _showCreateChecklistDialog,
          )
        else
          Column(
            children: <Widget>[
              for (final SmartChecklist checklist in checklists) ...<Widget>[
                _buildChecklistCard(context, ctrl, checklist),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildChecklistCard(
    BuildContext context,
    LifeOrganizationController ctrl,
    SmartChecklist checklist,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextEditingController itemCtrl = _itemControllerFor(checklist.id);

    return KayaCard(
      key: ValueKey<String>('checklist_card_${checklist.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(checklist.title, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      checklist.progressLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color:
                            checklist.totalCount > 0 &&
                                checklist.completedCount == checklist.totalCount
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (checklist.hasCompletedItems)
                TextButton.icon(
                  key: ValueKey<String>('checklist_reset_${checklist.id}'),
                  onPressed: ctrl.isMutating
                      ? null
                      : () => _handleResetChecklist(checklist),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset'),
                ),
              IconButton(
                key: ValueKey<String>('checklist_delete_${checklist.id}'),
                tooltip: 'Delete checklist',
                icon: const Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: AppColors.textMuted,
                ),
                onPressed: ctrl.isMutating
                    ? null
                    : () => _handleDeleteChecklist(checklist),
              ),
            ],
          ),
          if (checklist.totalCount > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: LinearProgressIndicator(
                value: checklist.progressRatio,
                minHeight: 5,
                backgroundColor: AppColors.background,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (checklist.items.isEmpty)
            Text(
              'No items yet. Add your first item below.',
              style: textTheme.bodySmall,
            )
          else
            Column(
              children: <Widget>[
                for (final ChecklistItemEntry item in checklist.items)
                  Row(
                    children: <Widget>[
                      IconButton(
                        key: ValueKey<String>(
                          'checklist_item_toggle_${item.id}',
                        ),
                        tooltip: item.isCompleted
                            ? 'Mark unchecked'
                            : 'Mark checked',
                        onPressed: ctrl.isMutating
                            ? null
                            : () => ctrl.toggleChecklistItem(
                                checklistId: checklist.id,
                                itemId: item.id,
                                isCompleted: !item.isCompleted,
                              ),
                        icon: Icon(
                          item.isCompleted
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: item.isCompleted
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.title,
                          style: textTheme.bodyMedium?.copyWith(
                            decoration: item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: item.isCompleted
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove item',
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        onPressed: ctrl.isMutating
                            ? null
                            : () => ctrl.deleteChecklistItem(
                                checklistId: checklist.id,
                                itemId: item.id,
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: ValueKey<String>(
                    'checklist_add_item_field_${checklist.id}',
                  ),
                  controller: itemCtrl,
                  enabled: !ctrl.isMutating,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleAddItem(checklist.id),
                  decoration: const InputDecoration(
                    labelText: 'Add item',
                    hintText: 'Type an item...',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              KayaButton(
                key: ValueKey<String>(
                  'checklist_add_item_button_${checklist.id}',
                ),
                label: 'Add',
                variant: KayaButtonVariant.secondary,
                onPressed: ctrl.isMutating
                    ? null
                    : () => _handleAddItem(checklist.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateChecklistDialog extends StatefulWidget {
  const _CreateChecklistDialog();

  @override
  State<_CreateChecklistDialog> createState() => _CreateChecklistDialogState();
}

class _CreateChecklistDialogState extends State<_CreateChecklistDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Checklist'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: TextFormField(
            key: const ValueKey<String>('checklist_form_title_field'),
            controller: _titleCtrl,
            autofocus: true,
            maxLength: LifeOrganizationValidators.maxTitleLength,
            decoration: const InputDecoration(
              labelText: 'Checklist Name',
              hintText: 'e.g., Weekend Trip Packing',
            ),
            validator: (String? val) =>
                LifeOrganizationValidators.validateTitle(
                  val,
                  fieldName: 'Checklist name',
                ),
          ),
        ),
      ),
      actions: <Widget>[
        KayaButton(
          label: 'Cancel',
          variant: KayaButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        KayaButton(
          key: const ValueKey<String>('checklist_form_save_button'),
          label: 'Create',
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_titleCtrl.text);
            }
          },
        ),
      ],
    );
  }
}
