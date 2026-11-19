import 'package:kaya/features/auth/domain/supported_currency.dart';

/// Supported measurement units matching PostgreSQL CHECK constraints.
enum ShoppingUnit {
  pcs(dbValue: 'pcs', label: 'pcs'),
  pack(dbValue: 'pack', label: 'pack'),
  kg(dbValue: 'kg', label: 'kg'),
  g(dbValue: 'g', label: 'g'),
  liter(dbValue: 'liter', label: 'L'),
  bottle(dbValue: 'bottle', label: 'bottle'),
  box(dbValue: 'box', label: 'box');

  const ShoppingUnit({required this.dbValue, required this.label});

  final String dbValue;
  final String label;

  static ShoppingUnit? tryFromDbValue(String? raw) {
    if (raw == null) {
      return null;
    }
    final String normalized = raw.trim().toLowerCase();
    for (final ShoppingUnit unit in ShoppingUnit.values) {
      if (unit.dbValue == normalized) {
        return unit;
      }
    }
    return null;
  }
}

/// Product row inside a [ShoppingList] using integer minor currency units.
///
/// Strictly represents an estimated shopping cost and is never recorded
/// automatically as an actual expense.
class ShoppingProductItem {
  const ShoppingProductItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.estimatedUnitPriceMinor,
    required this.isPurchased,
  });

  final String id;
  final String name;
  final int quantity;
  final ShoppingUnit unit;
  final int estimatedUnitPriceMinor;
  final bool isPurchased;

  int get lineEstimatedTotalMinor => quantity * estimatedUnitPriceMinor;

  ShoppingProductItem copyWith({
    String? id,
    String? name,
    int? quantity,
    ShoppingUnit? unit,
    int? estimatedUnitPriceMinor,
    bool? isPurchased,
  }) {
    return ShoppingProductItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedUnitPriceMinor:
          estimatedUnitPriceMinor ?? this.estimatedUnitPriceMinor,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }
}

/// Shopping list aggregating estimated and remaining totals in minor units
/// without touching actual financial expenses (Phase 7).
class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.userId,
    required this.title,
    required this.currency,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final SupportedCurrency currency;
  final List<ShoppingProductItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalCount => items.length;

  int get purchasedCount =>
      items.where((ShoppingProductItem item) => item.isPurchased).length;

  int get remainingCount => totalCount - purchasedCount;

  /// Sum of all products' estimated totals in minor units.
  int get estimatedTotalMinor {
    int sum = 0;
    for (final ShoppingProductItem item in items) {
      sum += item.lineEstimatedTotalMinor;
    }
    return sum;
  }

  /// Sum of purchased products' estimated totals in minor units.
  int get purchasedTotalMinor {
    int sum = 0;
    for (final ShoppingProductItem item in items) {
      if (item.isPurchased) {
        sum += item.lineEstimatedTotalMinor;
      }
    }
    return sum;
  }

  /// Remaining unpurchased estimated total in minor units.
  int get remainingTotalMinor => estimatedTotalMinor - purchasedTotalMinor;

  ShoppingList copyWith({
    String? id,
    String? userId,
    String? title,
    SupportedCurrency? currency,
    List<ShoppingProductItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      currency: currency ?? this.currency,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
