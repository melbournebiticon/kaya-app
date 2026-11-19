import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/bill_reminder_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/domain/bill_enums.dart';
import 'package:kaya/features/bills/domain/bill_item.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:material_ui/material_ui.dart';

/// Modal dialog for creating or editing a bill in Phase 5.
class BillFormDialog extends StatefulWidget {
  const BillFormDialog({
    super.key,
    required this.controller,
    this.existingBill,
  });

  final BillController controller;
  final BillItem? existingBill;

  static Future<bool> show(
    BuildContext context, {
    required BillController controller,
    BillItem? existingBill,
  }) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) =>
          BillFormDialog(controller: controller, existingBill: existingBill),
    );
    return saved ?? false;
  }

  @override
  State<BillFormDialog> createState() => _BillFormDialogState();
}

class _BillFormDialogState extends State<BillFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late BillCategory _category;
  late BillRecurrence _recurrence;
  late KayaDateOnly _dueDate;

  bool get _isEditing => widget.existingBill != null;

  @override
  void initState() {
    super.initState();
    final BillItem? existing = widget.existingBill;
    final SupportedCurrency currency =
        existing?.currency ?? widget.controller.activeCurrency;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
      text: existing != null
          ? MoneyFormatter.formatEditableInput(existing.amountMinor, currency)
          : '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _category = existing?.category ?? BillCategory.utilities;
    _recurrence = existing?.recurrence ?? BillRecurrence.oneTime;
    _dueDate = existing?.dueDate ?? widget.controller.referenceToday;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.toLocalDateTime(),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _dueDate = KayaDateOnly.fromDateTime(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final SupportedCurrency currency =
        widget.existingBill?.currency ?? widget.controller.activeCurrency;
    final int? amountMinor = MoneyFormatter.tryParseMinorUnits(
      _amountController.text,
      currency,
    );
    if (amountMinor == null || amountMinor <= 0) {
      return;
    }

    final bool success;
    if (_isEditing) {
      success = await widget.controller.updateBill(
        billId: widget.existingBill!.id,
        title: _titleController.text,
        notes: _notesController.text,
        category: _category,
        amountMinor: amountMinor,
        currency: currency,
        dueDate: _dueDate,
        recurrence: _recurrence,
      );
    } else {
      success = await widget.controller.createBill(
        title: _titleController.text,
        notes: _notesController.text,
        category: _category,
        amountMinor: amountMinor,
        dueDate: _dueDate,
        recurrence: _recurrence,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SupportedCurrency currency =
        widget.existingBill?.currency ?? widget.controller.activeCurrency;
    final KayaDateOnly today = widget.controller.referenceToday;
    final KayaDateOnly tomorrow = today.addDays(1);
    final KayaDateOnly nextWeek = today.addDays(7);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final bool isMutating = widget.controller.isMutating;
        final String? errorMessage = widget.controller.errorMessage;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Text(_isEditing ? 'Edit Bill' : 'Add New Bill'),
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
                      key: const ValueKey<String>('bill_form_title_field'),
                      controller: _titleController,
                      enabled: !isMutating,
                      maxLength: BillReminderValidators.maxTitleLength,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Bill Name',
                        hintText: 'e.g., Meralco Electric Bill',
                      ),
                      validator: (String? val) =>
                          BillReminderValidators.validateTitle(
                            val,
                            fieldName: 'Bill name',
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('bill_form_amount_field'),
                      controller: _amountController,
                      enabled: !isMutating,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: currency.minorUnits > 0,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Bill Amount (${currency.code})',
                        prefixText: '${currency.symbol} ',
                        hintText: currency.minorUnits == 0 ? '2500' : '2500.00',
                      ),
                      validator: (String? val) =>
                          BillReminderValidators.validateBillAmountInput(
                            val,
                            currency,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<BillCategory>(
                      key: const ValueKey<String>(
                        'bill_form_category_dropdown',
                      ),
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: <DropdownMenuItem<BillCategory>>[
                        for (final BillCategory item in BillCategory.values)
                          DropdownMenuItem<BillCategory>(
                            value: item,
                            child: Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: isMutating
                          ? null
                          : (BillCategory? next) {
                              if (next != null) {
                                setState(() => _category = next);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<BillRecurrence>(
                      key: const ValueKey<String>(
                        'bill_form_recurrence_dropdown',
                      ),
                      initialValue: _recurrence,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Recurrence Schedule',
                      ),
                      items: <DropdownMenuItem<BillRecurrence>>[
                        for (final BillRecurrence item in BillRecurrence.values)
                          DropdownMenuItem<BillRecurrence>(
                            value: item,
                            child: Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: isMutating
                          ? null
                          : (BillRecurrence? next) {
                              if (next != null) {
                                setState(() => _recurrence = next);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Due Date', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Today'),
                          selected: _dueDate == today,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() => _dueDate = today),
                        ),
                        ChoiceChip(
                          label: const Text('Tomorrow'),
                          selected: _dueDate == tomorrow,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() => _dueDate = tomorrow),
                        ),
                        ChoiceChip(
                          label: const Text('Next Week'),
                          selected: _dueDate == nextWeek,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() => _dueDate = nextWeek),
                        ),
                        ActionChip(
                          key: const ValueKey<String>(
                            'bill_form_date_picker_button',
                          ),
                          avatar: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          label: Text(_dueDate.formatReadable()),
                          onPressed: isMutating ? null : _pickDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('bill_form_notes_field'),
                      controller: _notesController,
                      enabled: !isMutating,
                      maxLength: BillReminderValidators.maxNotesLength,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Account number reference or payment channel',
                      ),
                      validator: BillReminderValidators.validateNotes,
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
              key: const ValueKey<String>('bill_form_save_button'),
              label: _isEditing ? 'Save Changes' : 'Save Bill',
              isLoading: isMutating,
              onPressed: isMutating ? null : _handleSave,
            ),
          ],
        );
      },
    );
  }
}
