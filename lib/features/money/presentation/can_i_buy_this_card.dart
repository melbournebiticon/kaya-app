import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/money/domain/safe_to_spend_calculator.dart';
import 'package:material_ui/material_ui.dart';

/// Interactive "Can I Buy This?" evaluator card.
///
/// Strictly separates estimates from actual transactions: evaluating a
/// planned purchase never inserts or modifies an expense record.
class CanIBuyThisCard extends StatefulWidget {
  const CanIBuyThisCard({super.key, required this.controller});

  final MoneyController controller;

  @override
  State<CanIBuyThisCard> createState() => _CanIBuyThisCardState();
}

class _CanIBuyThisCardState extends State<CanIBuyThisCard> {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handleEvaluate() {
    widget.controller.evaluateCanIBuyThis(
      rawAmountInput: _amountController.text,
      itemLabel: _itemController.text,
    );
  }

  void _handleClear() {
    _itemController.clear();
    _amountController.clear();
    widget.controller.clearPurchaseEvaluation();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final SupportedCurrency currency = widget.controller.activeCurrency;
        final PurchaseAffordabilityVerdict? verdict =
            widget.controller.lastPurchaseVerdict;
        final String? validationError =
            widget.controller.purchaseValidationError;

        return KayaCard(
          padding: AppSpacing.cardPaddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Can I Buy This?', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Test a planned purchase against your Safe to Spend — estimates are never saved as expenses.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stackFields = constraints.maxWidth < 520;
                  final Widget itemField = TextField(
                    key: const ValueKey<String>('can_i_buy_item_field'),
                    controller: _itemController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Item or Purchase (Optional)',
                      hintText: 'e.g., Running Shoes',
                    ),
                  );
                  final Widget priceField = TextField(
                    key: const ValueKey<String>('can_i_buy_amount_field'),
                    controller: _amountController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: currency.minorUnits > 0,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleEvaluate(),
                    decoration: InputDecoration(
                      labelText: 'Planned Price (${currency.code})',
                      prefixText: '${currency.symbol} ',
                      hintText: currency.minorUnits == 0 ? '2500' : '1250.00',
                    ),
                  );

                  if (stackFields) {
                    return Column(
                      children: <Widget>[
                        itemField,
                        const SizedBox(height: AppSpacing.sm),
                        priceField,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 3, child: itemField),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(flex: 2, child: priceField),
                    ],
                  );
                },
              ),
              if (validationError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  validationError,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  KayaButton(
                    key: const ValueKey<String>('can_i_buy_check_button'),
                    label: 'Check Affordability',
                    icon: Icons.fact_check_outlined,
                    variant: KayaButtonVariant.secondary,
                    onPressed: _handleEvaluate,
                  ),
                  if (verdict != null || validationError != null)
                    KayaButton(
                      label: 'Clear',
                      variant: KayaButtonVariant.ghost,
                      onPressed: _handleClear,
                    ),
                ],
              ),
              if (verdict != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _VerdictBanner(verdict: verdict),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.verdict});

  final PurchaseAffordabilityVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final KayaStatusType statusType = switch (verdict.health) {
      SafeToSpendHealth.healthy => KayaStatusType.positive,
      SafeToSpendHealth.caution => KayaStatusType.warning,
      SafeToSpendHealth.critical => KayaStatusType.critical,
      SafeToSpendHealth.unconfigured => KayaStatusType.neutral,
    };

    final Color bgColor = switch (verdict.health) {
      SafeToSpendHealth.healthy => AppColors.successSurface,
      SafeToSpendHealth.caution => AppColors.warningSurface,
      SafeToSpendHealth.critical => AppColors.errorSurface,
      SafeToSpendHealth.unconfigured => AppColors.surfaceElevated,
    };

    final Color borderColor = switch (verdict.health) {
      SafeToSpendHealth.healthy => AppColors.success.withValues(alpha: 0.45),
      SafeToSpendHealth.caution => AppColors.warning.withValues(alpha: 0.45),
      SafeToSpendHealth.critical => AppColors.error.withValues(alpha: 0.45),
      SafeToSpendHealth.unconfigured => AppColors.border,
    };

    final SupportedCurrency currency = verdict.currency;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          KayaStatusBadge(
            label: verdict.headline,
            type: statusType,
            customIcon: verdict.canSafelyAfford
                ? Icons.check_circle_outline
                : Icons.block_outlined,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(verdict.explanation, style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Before: ${MoneyFormatter.formatMinorUnits(verdict.safeToSpendBeforeMinor, currency)}  •  After: ${MoneyFormatter.formatMinorUnits(verdict.safeToSpendAfterMinor, currency)}',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
