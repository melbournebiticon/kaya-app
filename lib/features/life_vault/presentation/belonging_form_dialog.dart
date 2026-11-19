import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/life_vault_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/domain/belonging_item.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:material_ui/material_ui.dart';

/// Modal dialog for creating or editing a personal [BelongingItem] or
/// borrowed/lent tracking entry.
class BelongingFormDialog extends StatefulWidget {
  const BelongingFormDialog({
    super.key,
    required this.controller,
    this.existingBelonging,
  });

  final LifeVaultController controller;
  final BelongingItem? existingBelonging;

  static Future<bool> show(
    BuildContext context, {
    required LifeVaultController controller,
    BelongingItem? existingBelonging,
  }) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => BelongingFormDialog(
        controller: controller,
        existingBelonging: existingBelonging,
      ),
    );
    return saved ?? false;
  }

  @override
  State<BelongingFormDialog> createState() => _BelongingFormDialogState();
}

class _BelongingFormDialogState extends State<BelongingFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _counterpartyController;
  late final TextEditingController _notesController;

  late BelongingCategory _category;
  late BelongingCustodyType _custodyType;
  KayaDateOnly? _dueReturnDate;

  bool get _isEditing => widget.existingBelonging != null;

  @override
  void initState() {
    super.initState();
    final BelongingItem? existing = widget.existingBelonging;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _locationController = TextEditingController(
      text: existing?.storageLocation ?? '',
    );
    _counterpartyController = TextEditingController(
      text: existing?.counterpartyName ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _category = existing?.category ?? BelongingCategory.electronics;
    _custodyType = existing?.custodyType ?? BelongingCustodyType.owned;
    _dueReturnDate = existing?.dueReturnDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _counterpartyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReturnDate() async {
    final KayaDateOnly initial =
        _dueReturnDate ?? widget.controller.referenceToday.addDays(7);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.toLocalDateTime(),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _dueReturnDate = KayaDateOnly.fromDateTime(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final bool success;
    if (_isEditing) {
      success = await widget.controller.updateBelonging(
        belongingId: widget.existingBelonging!.id,
        title: _titleController.text,
        category: _category,
        storageLocation: _locationController.text,
        notes: _notesController.text,
        custodyType: _custodyType,
        counterpartyName: _counterpartyController.text,
        dueReturnDate: _dueReturnDate,
      );
    } else {
      success = await widget.controller.createBelonging(
        title: _titleController.text,
        category: _category,
        storageLocation: _locationController.text,
        notes: _notesController.text,
        custodyType: _custodyType,
        counterpartyName: _counterpartyController.text,
        dueReturnDate: _dueReturnDate,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final KayaDateOnly today = widget.controller.referenceToday;
    final KayaDateOnly nextWeek = today.addDays(7);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final bool isMutating = widget.controller.isMutating;
        final String? errorMessage = widget.controller.errorMessage;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Text(_isEditing ? 'Edit Belonging' : 'Add Personal Belonging'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (errorMessage != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.errorSurface,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Text(
                          errorMessage,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text('Item Custody Status', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          key: const ValueKey<String>('blg_form_custody_owned'),
                          label: const Text('In My Possession'),
                          selected: _custodyType == BelongingCustodyType.owned,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() {
                                  _custodyType = BelongingCustodyType.owned;
                                  _dueReturnDate = null;
                                }),
                        ),
                        ChoiceChip(
                          key: const ValueKey<String>(
                            'blg_form_custody_lent_out',
                          ),
                          label: const Text('Lent Out'),
                          selected:
                              _custodyType == BelongingCustodyType.lentOut,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() {
                                  _custodyType = BelongingCustodyType.lentOut;
                                }),
                        ),
                        ChoiceChip(
                          key: const ValueKey<String>(
                            'blg_form_custody_borrowed',
                          ),
                          label: const Text('Borrowed'),
                          selected:
                              _custodyType == BelongingCustodyType.borrowed,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() {
                                  _custodyType = BelongingCustodyType.borrowed;
                                }),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('blg_form_title_field'),
                      controller: _titleController,
                      enabled: !isMutating,
                      maxLength: LifeVaultValidators.maxTextLength,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g., Cordless Drill or Camera Lens',
                      ),
                      validator: (String? val) =>
                          LifeVaultValidators.validateRequiredText(
                            val,
                            fieldName: 'Item name',
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<BelongingCategory>(
                      key: const ValueKey<String>('blg_form_category_dropdown'),
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: <DropdownMenuItem<BelongingCategory>>[
                        for (final BelongingCategory cat
                            in BelongingCategory.values)
                          DropdownMenuItem<BelongingCategory>(
                            value: cat,
                            child: Text(
                              cat.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: isMutating
                          ? null
                          : (BelongingCategory? next) {
                              if (next != null) {
                                setState(() => _category = next);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('blg_form_location_field'),
                      controller: _locationController,
                      enabled: !isMutating,
                      maxLength: LifeVaultValidators.maxTextLength,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Home Storage Location',
                        hintText: 'e.g., Garage Shelf B or Study Cabinet',
                      ),
                      validator: (String? val) =>
                          LifeVaultValidators.validateRequiredText(
                            val,
                            fieldName: 'Storage location',
                          ),
                    ),
                    if (_custodyType.requiresCounterparty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const ValueKey<String>(
                          'blg_form_counterparty_field',
                        ),
                        controller: _counterpartyController,
                        enabled: !isMutating,
                        maxLength: LifeVaultValidators.maxTextLength,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText:
                              _custodyType == BelongingCustodyType.lentOut
                              ? 'Lent To (Person)'
                              : 'Borrowed From (Person)',
                          hintText: 'e.g., Marco Santos',
                        ),
                        validator: (String? val) =>
                            LifeVaultValidators.validateCounterparty(
                              requiresCounterparty: true,
                              counterpartyName: val,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Expected Return Date (Optional)',
                        style: textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          ChoiceChip(
                            label: const Text('In 7 Days'),
                            selected: _dueReturnDate == nextWeek,
                            onSelected: isMutating
                                ? null
                                : (_) =>
                                      setState(() => _dueReturnDate = nextWeek),
                          ),
                          ChoiceChip(
                            label: const Text('No Return Date'),
                            selected: _dueReturnDate == null,
                            onSelected: isMutating
                                ? null
                                : (_) => setState(() => _dueReturnDate = null),
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                            ),
                            label: Text(
                              _dueReturnDate?.formatReadable() ?? 'Pick Date',
                            ),
                            onPressed: isMutating ? null : _pickReturnDate,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('blg_form_notes_field'),
                      controller: _notesController,
                      enabled: !isMutating,
                      maxLength: LifeVaultValidators.maxNotesLength,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Condition, accessories included, or context',
                      ),
                      validator: LifeVaultValidators.validateNotes,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            KayaButton(
              label: 'Cancel',
              variant: KayaButtonVariant.ghost,
              onPressed: isMutating
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
            KayaButton(
              key: const ValueKey<String>('blg_form_save_button'),
              label: _isEditing ? 'Save Changes' : 'Save Belonging',
              isLoading: isMutating,
              onPressed: isMutating ? null : _handleSave,
            ),
          ],
        );
      },
    );
  }
}
