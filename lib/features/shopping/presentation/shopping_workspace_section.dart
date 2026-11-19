import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/validation/life_organization_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/money/domain/money_formatter.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/shopping/domain/shopping_list.dart';
import 'package:material_ui/material_ui.dart';

/// Shopping Lists workspace inside [LifeScreen] (Phase 7).
///
/// Strictly separates estimated shopping totals from actual financial expenses.
class ShoppingWorkspaceSection extends StatefulWidget {
  const ShoppingWorkspaceSection({super.key, required this.controller});

  final LifeOrganizationController controller;

  @override
  State<ShoppingWorkspaceSection> createState() =>
      _ShoppingWorkspaceSectionState();
}

class _ShoppingWorkspaceSectionState extends State<ShoppingWorkspaceSection> {
  Future<void> _showCreateListDialog() async {
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) =>
          const _CreateShoppingListDialog(),
    );

    if (title != null) {
      await widget.controller.createShoppingList(title: title);
    }
  }

  Future<void> _showAddProductDialog(ShoppingList list) async {
    final _AddShoppingProductResult? result =
        await showDialog<_AddShoppingProductResult>(
          context: context,
          builder: (BuildContext dialogContext) => _AddShoppingProductDialog(
            listTitle: list.title,
            currency: list.currency,
          ),
        );

    if (result != null) {
      await widget.controller.addShoppingProduct(
        shoppingListId: list.id,
        name: result.name,
        quantity: result.quantity,
        unit: result.unit,
        estimatedUnitPriceMinor: result.estimatedUnitPriceMinor,
      );
    }
  }

  Future<void> _handleDeleteList(ShoppingList list) async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Delete Shopping List?',
      message: 'Are you sure you want to delete "${list.title}" and its items?',
      confirmLabel: 'Delete List',
    );
    if (confirmed) {
      await widget.controller.deleteShoppingList(list.id);
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
    final List<ShoppingList> lists = ctrl.shoppingLists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KayaSectionHeader(
          title: 'Shopping Lists',
          subtitle: 'Plan quantities and estimated prices without altering actual Money expenses',
          trailing: KayaButton(
            key: const ValueKey<String>('shopping_create_list_button'),
            label: 'New List',
            icon: Icons.add,
            onPressed: ctrl.isMutating ? null : _showCreateListDialog,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (ctrl.isLoading && lists.isEmpty)
          const KayaLoadingState(
            title: 'Loading shopping lists...',
            subtitle: 'Preparing planned items and estimates.',
          )
        else if (ctrl.hasLoadError)
          KayaErrorState(
            title: 'Unable to Load Shopping Lists',
            message:
                ctrl.errorMessage ??
                'Could not fetch shopping lists. Please try again.',
            onRetry: ctrl.loadAll,
          )
        else if (lists.isEmpty)
          KayaEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No Shopping Lists Yet',
            description: 'Track groceries or supplies with quantities and estimated prices. Checked items remain estimates until you log an actual expense in Money.',
            actionLabel: 'Create Shopping List',
            onAction: _showCreateListDialog,
          )
        else
          Column(
            children: <Widget>[
              for (final ShoppingList list in lists) ...<Widget>[
                _buildShoppingListCard(context, ctrl, list),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildShoppingListCard(
    BuildContext context,
    LifeOrganizationController ctrl,
    ShoppingList list,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String estFormatted = MoneyFormatter.formatMinorUnits(
      list.estimatedTotalMinor,
      list.currency,
    );
    final String remainingFormatted = MoneyFormatter.formatMinorUnits(
      list.remainingTotalMinor,
      list.currency,
    );

    return KayaCard(
      key: ValueKey<String>('shopping_list_card_${list.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(list.title, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Estimate only • ${list.purchasedCount}/${list.totalCount} purchased',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: ValueKey<String>('shopping_add_product_button_${list.id}'),
                onPressed: ctrl.isMutating
                    ? null
                    : () => _showAddProductDialog(list),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
              ),
              IconButton(
                key: ValueKey<String>('shopping_list_delete_${list.id}'),
                tooltip: 'Delete shopping list',
                icon: const Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: AppColors.textMuted,
                ),
                onPressed: ctrl.isMutating
                    ? null
                    : () => _handleDeleteList(list),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: <Widget>[
              Text(
                'Est. Total: $estFormatted',
                key: ValueKey<String>('shopping_estimated_total_${list.id}'),
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Remaining: $remainingFormatted',
                key: ValueKey<String>('shopping_remaining_total_${list.id}'),
                style: textTheme.labelMedium?.copyWith(
                  color: list.remainingTotalMinor > 0
                      ? AppColors.primary
                      : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.xs),
          if (list.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                'No products yet. Tap Add Item to add groceries or supplies.',
                style: textTheme.bodySmall,
              ),
            )
          else
            Column(
              children: <Widget>[
                for (final ShoppingProductItem item in list.items)
                  Row(
                    children: <Widget>[
                      IconButton(
                        key: ValueKey<String>(
                          'shopping_product_toggle_${item.id}',
                        ),
                        tooltip: item.isPurchased
                            ? 'Mark unpurchased'
                            : 'Mark purchased',
                        onPressed: ctrl.isMutating
                            ? null
                            : () => ctrl.toggleShoppingProductPurchased(
                                shoppingListId: list.id,
                                productId: item.id,
                                isPurchased: !item.isPurchased,
                              ),
                        icon: Icon(
                          item.isPurchased
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: item.isPurchased
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.name,
                              style: textTheme.bodyMedium?.copyWith(
                                decoration: item.isPurchased
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isPurchased
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${item.quantity} ${item.unit.label} × ${MoneyFormatter.formatMinorUnits(item.estimatedUnitPriceMinor, list.currency)}',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        MoneyFormatter.formatMinorUnits(
                          item.lineEstimatedTotalMinor,
                          list.currency,
                        ),
                        style: textTheme.labelMedium?.copyWith(
                          color: item.isPurchased
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
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
                            : () => ctrl.deleteShoppingProduct(
                                shoppingListId: list.id,
                                productId: item.id,
                              ),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CreateShoppingListDialog extends StatefulWidget {
  const _CreateShoppingListDialog();

  @override
  State<_CreateShoppingListDialog> createState() =>
      _CreateShoppingListDialogState();
}

class _CreateShoppingListDialogState extends State<_CreateShoppingListDialog> {
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
      title: const Text('New Shopping List'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: TextFormField(
            key: const ValueKey<String>('shopping_list_title_field'),
            controller: _titleCtrl,
            autofocus: true,
            maxLength: LifeOrganizationValidators.maxTitleLength,
            decoration: const InputDecoration(
              labelText: 'List Name',
              hintText: 'e.g., Weekly Groceries',
            ),
            validator: (String? val) =>
                LifeOrganizationValidators.validateTitle(
                  val,
                  fieldName: 'Shopping list name',
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
          key: const ValueKey<String>('shopping_list_save_button'),
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

class _AddShoppingProductResult {
  const _AddShoppingProductResult({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.estimatedUnitPriceMinor,
  });

  final String name;
  final int quantity;
  final ShoppingUnit unit;
  final int estimatedUnitPriceMinor;
}

class _AddShoppingProductDialog extends StatefulWidget {
  const _AddShoppingProductDialog({
    required this.listTitle,
    required this.currency,
  });

  final String listTitle;
  final SupportedCurrency currency;

  @override
  State<_AddShoppingProductDialog> createState() =>
      _AddShoppingProductDialogState();
}

class _AddShoppingProductDialogState extends State<_AddShoppingProductDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _priceCtrl = TextEditingController(text: '0');
  ShoppingUnit _unit = ShoppingUnit.pcs;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SupportedCurrency currency = widget.currency;
    return AlertDialog(
      title: Text('Add Item to ${widget.listTitle}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  key: const ValueKey<String>('shopping_product_name_field'),
                  controller: _nameCtrl,
                  autofocus: true,
                  maxLength: LifeOrganizationValidators.maxTitleLength,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g., Fresh Milk',
                  ),
                  validator: (String? val) =>
                      LifeOrganizationValidators.validateTitle(
                        val,
                        fieldName: 'Product name',
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey<String>(
                          'shopping_product_qty_field',
                        ),
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        validator:
                            LifeOrganizationValidators.validateQuantityInput,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<ShoppingUnit>(
                        key: const ValueKey<String>(
                          'shopping_product_unit_dropdown',
                        ),
                        initialValue: _unit,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: <DropdownMenuItem<ShoppingUnit>>[
                          for (final ShoppingUnit u in ShoppingUnit.values)
                            DropdownMenuItem<ShoppingUnit>(
                              value: u,
                              child: Text(
                                u.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (ShoppingUnit? next) {
                          if (next != null) {
                            setState(() => _unit = next);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const ValueKey<String>('shopping_product_price_field'),
                  controller: _priceCtrl,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: currency.minorUnits > 0,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Estimated Unit Price (${currency.code})',
                    prefixText: '${currency.symbol} ',
                  ),
                  validator: (String? val) =>
                      LifeOrganizationValidators.validateEstimatedPriceInput(
                        val,
                        currency,
                      ),
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        KayaButton(
          key: const ValueKey<String>('shopping_product_save_button'),
          label: 'Add Item',
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final int? qty = int.tryParse(_qtyCtrl.text.trim());
              final int? priceMinor = MoneyFormatter.tryParseMinorUnits(
                _priceCtrl.text,
                currency,
              );
              if (qty != null && priceMinor != null) {
                Navigator.of(context).pop(
                  _AddShoppingProductResult(
                    name: _nameCtrl.text,
                    quantity: qty,
                    unit: _unit,
                    estimatedUnitPriceMinor: priceMinor,
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }
}
