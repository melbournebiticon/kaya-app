import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/domain/money_enums.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/money_transaction.dart';
import 'package:material_ui/material_ui.dart';

/// Modal dialog for recording or editing an actual income or expense transaction.
class TransactionFormDialog extends StatefulWidget {
  const TransactionFormDialog({
    super.key,
    required this.controller,
    this.initialType = TransactionType.expense,
    this.existingTransaction,
  });

  final MoneyController controller;
  final TransactionType initialType;
  final MoneyTransaction? existingTransaction;

  static Future<bool> show(
    BuildContext context, {
    required MoneyController controller,
    TransactionType initialType = TransactionType.expense,
    MoneyTransaction? existingTransaction,
  }) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => TransactionFormDialog(
        controller: controller,
        initialType: initialType,
        existingTransaction: existingTransaction,
      ),
    );
    return saved ?? false;
  }

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late TransactionType _type;
  late MoneyCategory _category;
  late KayaDateOnly _transactionDate;

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final MoneyTransaction? existing = widget.existingTransaction;
    final SupportedCurrency currency = widget.controller.activeCurrency;

    _type = existing?.type ?? widget.initialType;
    _category = existing?.category ?? MoneyCategory.defaultForType(_type);
    _transactionDate =
        existing?.transactionDate ?? widget.controller.referenceToday;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
      text: existing != null
          ? MoneyFormatter.formatEditableInput(existing.amountMinor, currency)
          : '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectType(TransactionType nextType) {
    if (_type == nextType) {
      return;
    }
    setState(() {
      _type = nextType;
      if (_category.transactionType != nextType) {
        _category = MoneyCategory.defaultForType(nextType);
      }
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate.toLocalDateTime(),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _transactionDate = KayaDateOnly.fromDateTime(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final SupportedCurrency currency = widget.controller.activeCurrency;
    final int? amountMinor = MoneyFormatter.tryParseMinorUnits(
      _amountController.text,
      currency,
    );
    if (amountMinor == null || amountMinor <= 0) {
      return;
    }

    final bool success;
    if (_isEditing) {
      success = await widget.controller.updateTransaction(
        transactionId: widget.existingTransaction!.id,
        type: _type,
        category: _category,
        title: _titleController.text,
        notes: _notesController.text,
        amountMinor: amountMinor,
        transactionDate: _transactionDate,
      );
    } else {
      success = await widget.controller.createTransaction(
        type: _type,
        category: _category,
        title: _titleController.text,
        notes: _notesController.text,
        amountMinor: amountMinor,
        transactionDate: _transactionDate,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SupportedCurrency currency = widget.controller.activeCurrency;
    final List<MoneyCategory> categories = MoneyCategory.forType(_type);
    final KayaDateOnly today = widget.controller.referenceToday;
    final KayaDateOnly yesterday = today.addDays(-1);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final bool isMutating = widget.controller.isMutating;
        final String? errorMessage = widget.controller.errorMessage;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Text(_isEditing ? 'Edit Transaction' : 'Record Transaction'),
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
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          key: const ValueKey<String>('tx_form_type_expense'),
                          label: const Text('Expense'),
                          selected: _type == TransactionType.expense,
                          onSelected: isMutating
                              ? null
                              : (_) => _selectType(TransactionType.expense),
                        ),
                        ChoiceChip(
                          key: const ValueKey<String>('tx_form_type_income'),
                          label: const Text('Income'),
                          selected: _type == TransactionType.income,
                          onSelected: isMutating
                              ? null
                              : (_) => _selectType(TransactionType.income),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('tx_form_title_field'),
                      controller: _titleController,
                      enabled: !isMutating,
                      maxLength: MoneyValidators.maxTitleLength,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _type == TransactionType.income
                            ? 'Income Source'
                            : 'Expense Description',
                        hintText: _type == TransactionType.income
                            ? 'e.g., Monthly Salary'
                            : 'e.g., Groceries at Market',
                      ),
                      validator: MoneyValidators.validateTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('tx_form_amount_field'),
                      controller: _amountController,
                      enabled: !isMutating,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: currency.minorUnits > 0,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Amount (${currency.code})',
                        prefixText: '${currency.symbol} ',
                        hintText: currency.minorUnits == 0 ? '1500' : '500.00',
                      ),
                      validator: (String? val) =>
                          MoneyValidators.validatePositiveAmountInput(
                            val,
                            currency,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<MoneyCategory>(
                      key: const ValueKey<String>('tx_form_category_dropdown'),
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: <DropdownMenuItem<MoneyCategory>>[
                        for (final MoneyCategory item in categories)
                          DropdownMenuItem<MoneyCategory>(
                            value: item,
                            child: Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: isMutating
                          ? null
                          : (MoneyCategory? next) {
                              if (next != null) {
                                setState(() => _category = next);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Transaction Date', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('Today'),
                          selected: _transactionDate == today,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() => _transactionDate = today),
                        ),
                        ChoiceChip(
                          label: const Text('Yesterday'),
                          selected: _transactionDate == yesterday,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(
                                  () => _transactionDate = yesterday,
                                ),
                        ),
                        ActionChip(
                          key: const ValueKey<String>(
                            'tx_form_date_picker_button',
                          ),
                          avatar: const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                          ),
                          label: Text(_transactionDate.formatReadable()),
                          onPressed: isMutating ? null : _pickDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const ValueKey<String>('tx_form_notes_field'),
                      controller: _notesController,
                      enabled: !isMutating,
                      maxLength: MoneyValidators.maxNotesLength,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Receipt details, account used, or context',
                      ),
                      validator: MoneyValidators.validateNotes,
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
              key: const ValueKey<String>('tx_form_save_button'),
              label: _isEditing ? 'Save Changes' : 'Save Transaction',
              isLoading: isMutating,
              onPressed: isMutating ? null : _handleSave,
            ),
          ],
        );
      },
    );
  }
}
