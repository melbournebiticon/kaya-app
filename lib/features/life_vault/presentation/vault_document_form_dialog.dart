import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/life_vault_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:material_ui/material_ui.dart';

/// Modal dialog for creating or editing a protected [VaultDocument].
class VaultDocumentFormDialog extends StatefulWidget {
  const VaultDocumentFormDialog({
    super.key,
    required this.controller,
    this.existingDocument,
  });

  final LifeVaultController controller;
  final VaultDocument? existingDocument;

  static Future<bool> show(
    BuildContext context, {
    required LifeVaultController controller,
    VaultDocument? existingDocument,
  }) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => VaultDocumentFormDialog(
        controller: controller,
        existingDocument: existingDocument,
      ),
    );
    return saved ?? false;
  }

  @override
  State<VaultDocumentFormDialog> createState() =>
      _VaultDocumentFormDialogState();
}

class _VaultDocumentFormDialogState extends State<VaultDocumentFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;

  late DocumentCategory _category;
  KayaDateOnly? _issueDate;
  KayaDateOnly? _expirationDate;
  String? _dateValidationError;

  bool get _isEditing => widget.existingDocument != null;

  @override
  void initState() {
    super.initState();
    final VaultDocument? existing = widget.existingDocument;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _locationController = TextEditingController(
      text: existing?.physicalLocation ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _category = existing?.category ?? DocumentCategory.governmentId;
    _issueDate = existing?.issueDate;
    _expirationDate = existing?.expirationDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickIssueDate() async {
    final KayaDateOnly initial = _issueDate ?? widget.controller.referenceToday;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.toLocalDateTime(),
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _issueDate = KayaDateOnly.fromDateTime(picked);
        _dateValidationError = null;
      });
    }
  }

  Future<void> _pickExpirationDate() async {
    final KayaDateOnly initial =
        _expirationDate ?? widget.controller.referenceToday.addDays(15);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.toLocalDateTime(),
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _expirationDate = KayaDateOnly.fromDateTime(picked);
        _dateValidationError = null;
      });
    }
  }

  Future<void> _handleSave() async {
    final FormState? form = _formKey.currentState;
    final String? datesError = LifeVaultValidators.validateDocumentDates(
      issueDate: _issueDate,
      expirationDate: _expirationDate,
    );
    setState(() {
      _dateValidationError = datesError;
    });

    if (form == null || !form.validate() || datesError != null) {
      return;
    }

    final bool success;
    if (_isEditing) {
      success = await widget.controller.updateDocument(
        documentId: widget.existingDocument!.id,
        title: _titleController.text,
        category: _category,
        physicalLocation: _locationController.text,
        notes: _notesController.text,
        issueDate: _issueDate,
        expirationDate: _expirationDate,
      );
    } else {
      success = await widget.controller.createDocument(
        title: _titleController.text,
        category: _category,
        physicalLocation: _locationController.text,
        notes: _notesController.text,
        issueDate: _issueDate,
        expirationDate: _expirationDate,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final KayaDateOnly today = widget.controller.referenceToday;
    final KayaDateOnly in15Days = today.addDays(15);
    final KayaDateOnly in1Year = today.addYears(1);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final bool isMutating = widget.controller.isMutating;
        final String? errorMessage =
            _dateValidationError ?? widget.controller.errorMessage;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Text(_isEditing ? 'Edit Document' : 'Add Vault Document'),
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
                    TextFormField(
                      key: const ValueKey<String>('doc_form_title_field'),
                      controller: _titleController,
                      enabled: !isMutating,
                      maxLength: LifeVaultValidators.maxTextLength,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Document Title',
                        hintText: 'e.g., Philippine Passport',
                      ),
                      validator: (String? val) =>
                          LifeVaultValidators.validateRequiredText(
                            val,
                            fieldName: 'Document name',
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<DocumentCategory>(
                      key: const ValueKey<String>('doc_form_category_dropdown'),
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: <DropdownMenuItem<DocumentCategory>>[
                        for (final DocumentCategory cat
                            in DocumentCategory.values)
                          DropdownMenuItem<DocumentCategory>(
                            value: cat,
                            child: Text(
                              cat.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: isMutating
                          ? null
                          : (DocumentCategory? next) {
                              if (next != null) {
                                setState(() => _category = next);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('doc_form_location_field'),
                      controller: _locationController,
                      enabled: !isMutating,
                      maxLength: LifeVaultValidators.maxTextLength,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Physical Document Location',
                        hintText: 'e.g., Top Desk Drawer — Blue Folder',
                      ),
                      validator: (String? val) =>
                          LifeVaultValidators.validateRequiredText(
                            val,
                            fieldName: 'Physical location',
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Issue Date (Optional)', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          key: const ValueKey<String>(
                            'doc_form_issue_today_chip',
                          ),
                          label: const Text('Today'),
                          selected: _issueDate == today,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() {
                                  _issueDate = today;
                                  _dateValidationError = null;
                                }),
                        ),
                        ChoiceChip(
                          key: const ValueKey<String>(
                            'doc_form_issue_clear_chip',
                          ),
                          label: const Text('Not Set'),
                          selected: _issueDate == null,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() {
                                  _issueDate = null;
                                  _dateValidationError = null;
                                }),
                        ),
                        ActionChip(
                          key: const ValueKey<String>(
                            'doc_form_issue_date_button',
                          ),
                          avatar: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          label: Text(
                            _issueDate?.formatReadable() ?? 'Pick Issue Date',
                          ),
                          onPressed: isMutating ? null : _pickIssueDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Expiration Date (Optional)',
                      style: textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          key: const ValueKey<String>('doc_form_exp_15d_chip'),
                          label: const Text('In 15 Days'),
                          selected: _expirationDate == in15Days,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() {
                                  _expirationDate = in15Days;
                                  _dateValidationError = null;
                                }),
                        ),
                        ChoiceChip(
                          key: const ValueKey<String>('doc_form_exp_1y_chip'),
                          label: const Text('In 1 Year'),
                          selected: _expirationDate == in1Year,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() {
                                  _expirationDate = in1Year;
                                  _dateValidationError = null;
                                }),
                        ),
                        ChoiceChip(
                          key: const ValueKey<String>('doc_form_exp_none_chip'),
                          label: const Text('No Expiration'),
                          selected: _expirationDate == null,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() {
                                  _expirationDate = null;
                                  _dateValidationError = null;
                                }),
                        ),
                        ActionChip(
                          key: const ValueKey<String>(
                            'doc_form_exp_date_button',
                          ),
                          avatar: const Icon(Icons.event_outlined, size: 16),
                          label: Text(
                            _expirationDate?.formatReadable() ?? 'Pick Expiry',
                          ),
                          onPressed: isMutating ? null : _pickExpirationDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('doc_form_notes_field'),
                      controller: _notesController,
                      enabled: !isMutating,
                      maxLength: LifeVaultValidators.maxNotesLength,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Private Notes (Optional)',
                        hintText:
                            'Renewal steps or non-sensitive reference notes',
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
              key: const ValueKey<String>('doc_form_save_button'),
              label: _isEditing ? 'Save Changes' : 'Save Document',
              isLoading: isMutating,
              onPressed: isMutating ? null : _handleSave,
            ),
          ],
        );
      },
    );
  }
}
