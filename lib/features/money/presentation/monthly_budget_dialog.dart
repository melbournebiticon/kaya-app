import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/validation/money_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/monthly_budget.dart';
import 'package:material_ui/material_ui.dart';

/// Modal dialog for setting or updating the monthly spending budget limit.
class MonthlyBudgetDialog extends StatefulWidget {
  const MonthlyBudgetDialog({super.key, required this.controller});

  final MoneyController controller;

  static Future<bool> show(
    BuildContext context, {
    required MoneyController controller,
  }) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) =>
          MonthlyBudgetDialog(controller: controller),
    );
    return saved ?? false;
  }

  @override
  State<MonthlyBudgetDialog> createState() => _MonthlyBudgetDialogState();
}

class _MonthlyBudgetDialogState extends State<MonthlyBudgetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _limitController;

  @override
  void initState() {
    super.initState();
    final MonthlyBudget? existing = widget.controller.activeMonthlyBudget;
    final SupportedCurrency currency = widget.controller.activeCurrency;
    _limitController = TextEditingController(
      text: existing != null
          ? MoneyFormatter.formatEditableInput(
              existing.overallLimitMinor,
              currency,
            )
          : '',
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final int? limitMinor = MoneyFormatter.tryParseMinorUnits(
      _limitController.text,
      widget.controller.activeCurrency,
    );
    if (limitMinor == null || limitMinor <= 0) {
      return;
    }

    final bool saved = await widget.controller.saveMonthlyBudget(
      overallLimitMinor: limitMinor,
    );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SupportedCurrency currency = widget.controller.activeCurrency;
    final bool hasExisting = widget.controller.activeMonthlyBudget != null;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final bool isMutating = widget.controller.isMutating;
        final String? errorMessage = widget.controller.errorMessage;
        final TextTheme textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Text(
            hasExisting ? 'Update Monthly Budget' : 'Set Monthly Budget',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Spending ceiling for ${widget.controller.selectedPeriodLabel} (${currency.code}). KAYA uses this alongside your available balance to compute Safe to Spend.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                    key: const ValueKey<String>('budget_form_limit_field'),
                    controller: _limitController,
                    enabled: !isMutating,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: currency.minorUnits > 0,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monthly Limit (${currency.code})',
                      prefixText: '${currency.symbol} ',
                      hintText: currency.minorUnits == 0 ? '50000' : '15000.00',
                    ),
                    validator: (String? val) =>
                        MoneyValidators.validatePositiveAmountInput(
                          val,
                          currency,
                          fieldName: 'Monthly budget limit',
                        ),
                  ),
                ],
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
              key: const ValueKey<String>('budget_form_save_button'),
              label: 'Save Budget',
              isLoading: isMutating,
              onPressed: isMutating ? null : _handleSave,
            ),
          ],
        );
      },
    );
  }
}
