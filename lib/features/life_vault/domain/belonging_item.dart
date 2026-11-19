import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';

/// Immutable domain entity representing a personal belonging or borrowed/lent
/// item tracked in Life Vault (Phase 6).
///
/// Privacy rule (Section 7):
/// Redacts item title, storage location, counterparty, and notes in [toString].
class BelongingItem {
  const BelongingItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.storageLocation,
    required this.notes,
    required this.custodyType,
    required this.counterpartyName,
    required this.dueReturnDate,
    required this.isReturned,
    required this.returnedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final BelongingCategory category;
  final String storageLocation;
  final String notes;
  final BelongingCustodyType custodyType;
  final String counterpartyName;
  final KayaDateOnly? dueReturnDate;
  final bool isReturned;
  final DateTime? returnedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLoanItem => custodyType.requiresCounterparty;

  bool get isActiveLoan => isLoanItem && !isReturned;

  bool isReturnOverdue(KayaDateOnly referenceToday) {
    final KayaDateOnly? due = dueReturnDate;
    return isActiveLoan && due != null && due.isBefore(referenceToday);
  }

  String custodyStatusLabel(KayaDateOnly referenceToday) {
    if (custodyType == BelongingCustodyType.owned) {
      return 'Stored at $storageLocation';
    }
    if (isReturned) {
      return custodyType == BelongingCustodyType.lentOut
          ? 'Returned from $counterpartyName'
          : 'Returned to $counterpartyName';
    }
    final String base = custodyType == BelongingCustodyType.lentOut
        ? 'Lent to $counterpartyName'
        : 'Borrowed from $counterpartyName';
    if (dueReturnDate == null) {
      return base;
    }
    final int delta = dueReturnDate!.daysDifferenceFrom(referenceToday);
    if (delta < 0) {
      final int lateDays = -delta;
      return '$base • Return overdue ${lateDays}d';
    }
    if (delta == 0) {
      return '$base • Return today';
    }
    return '$base • Return ${dueReturnDate!.formatReadable()}';
  }

  BelongingItem copyWith({
    String? id,
    String? userId,
    String? title,
    BelongingCategory? category,
    String? storageLocation,
    String? notes,
    BelongingCustodyType? custodyType,
    String? counterpartyName,
    KayaDateOnly? dueReturnDate,
    bool clearDueReturnDate = false,
    bool? isReturned,
    DateTime? returnedAt,
    bool clearReturnedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BelongingItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      storageLocation: storageLocation ?? this.storageLocation,
      notes: notes ?? this.notes,
      custodyType: custodyType ?? this.custodyType,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      dueReturnDate: clearDueReturnDate
          ? null
          : (dueReturnDate ?? this.dueReturnDate),
      isReturned: isReturned ?? this.isReturned,
      returnedAt: clearReturnedAt ? null : (returnedAt ?? this.returnedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int compareByPriority(
    BelongingItem a,
    BelongingItem b,
    KayaDateOnly referenceToday,
  ) {
    int rank(BelongingItem item) {
      if (item.isReturnOverdue(referenceToday)) {
        return 0;
      }
      if (item.isActiveLoan) {
        return 1;
      }
      if (item.custodyType == BelongingCustodyType.owned) {
        return 2;
      }
      return 3;
    }

    final int rankCmp = rank(a).compareTo(rank(b));
    if (rankCmp != 0) {
      return rankCmp;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BelongingItem &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.category == category &&
        other.storageLocation == storageLocation &&
        other.notes == notes &&
        other.custodyType == custodyType &&
        other.counterpartyName == counterpartyName &&
        other.dueReturnDate == dueReturnDate &&
        other.isReturned == isReturned;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    category,
    storageLocation,
    notes,
    custodyType,
    counterpartyName,
    dueReturnDate,
    isReturned,
  );

  /// Redacts sensitive item names, locations, and personal contacts in logs.
  @override
  String toString() =>
      'BelongingItem(id: $id, category: ${category.dbValue}, custody: ${custodyType.dbValue}, title: [REDACTED], location: [REDACTED], counterparty: [REDACTED])';
}
