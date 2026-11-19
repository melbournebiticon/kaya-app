import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';

/// Immutable domain entity representing a protected document record in Life Vault.
///
/// Privacy rule (Section 7):
/// Never expose sensitive titles, locations, or notes in [toString] logs.
class VaultDocument {
  const VaultDocument({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.physicalLocation,
    required this.notes,
    required this.issueDate,
    required this.expirationDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Inclusive day threshold defining [DocumentExpirationStatus.expiringSoon].
  static const int expiringSoonWindowDays = 30;

  final String id;
  final String userId;
  final String title;
  final DocumentCategory category;
  final String physicalLocation;
  final String notes;
  final KayaDateOnly? issueDate;
  final KayaDateOnly? expirationDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentExpirationStatus expirationStatus(KayaDateOnly referenceToday) {
    final KayaDateOnly? exp = expirationDate;
    if (exp == null) {
      return DocumentExpirationStatus.noExpiration;
    }
    final int daysRemaining = exp.daysDifferenceFrom(referenceToday);
    if (daysRemaining < 0) {
      return DocumentExpirationStatus.expired;
    }
    if (daysRemaining <= expiringSoonWindowDays) {
      return DocumentExpirationStatus.expiringSoon;
    }
    return DocumentExpirationStatus.valid;
  }

  bool isExpired(KayaDateOnly referenceToday) =>
      expirationStatus(referenceToday) == DocumentExpirationStatus.expired;

  bool isExpiringSoon(KayaDateOnly referenceToday) =>
      expirationStatus(referenceToday) == DocumentExpirationStatus.expiringSoon;

  bool needsAttention(KayaDateOnly referenceToday) {
    final DocumentExpirationStatus status = expirationStatus(referenceToday);
    return status == DocumentExpirationStatus.expired ||
        status == DocumentExpirationStatus.expiringSoon;
  }

  String expirationStatusLabel(KayaDateOnly referenceToday) {
    final KayaDateOnly? exp = expirationDate;
    if (exp == null) {
      return 'No expiration';
    }
    final int daysRemaining = exp.daysDifferenceFrom(referenceToday);
    if (daysRemaining < 0) {
      final int overdue = -daysRemaining;
      return overdue == 1 ? 'Expired 1 day ago' : 'Expired $overdue days ago';
    }
    if (daysRemaining == 0) {
      return 'Expires today';
    }
    if (daysRemaining <= expiringSoonWindowDays) {
      return daysRemaining == 1
          ? 'Expiring in 1 day'
          : 'Expiring in $daysRemaining days';
    }
    return 'Valid until ${exp.formatReadable()}';
  }

  VaultDocument copyWith({
    String? id,
    String? userId,
    String? title,
    DocumentCategory? category,
    String? physicalLocation,
    String? notes,
    KayaDateOnly? issueDate,
    bool clearIssueDate = false,
    KayaDateOnly? expirationDate,
    bool clearExpirationDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultDocument(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      physicalLocation: physicalLocation ?? this.physicalLocation,
      notes: notes ?? this.notes,
      issueDate: clearIssueDate ? null : (issueDate ?? this.issueDate),
      expirationDate: clearExpirationDate
          ? null
          : (expirationDate ?? this.expirationDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int compareByUrgency(
    VaultDocument a,
    VaultDocument b,
    KayaDateOnly referenceToday,
  ) {
    int rank(VaultDocument doc) =>
        switch (doc.expirationStatus(referenceToday)) {
          DocumentExpirationStatus.expired => 0,
          DocumentExpirationStatus.expiringSoon => 1,
          DocumentExpirationStatus.valid => 2,
          DocumentExpirationStatus.noExpiration => 3,
        };

    final int rankCmp = rank(a).compareTo(rank(b));
    if (rankCmp != 0) {
      return rankCmp;
    }

    if (a.expirationDate != null && b.expirationDate != null) {
      final int expCmp = a.expirationDate!.compareTo(b.expirationDate!);
      if (expCmp != 0) {
        return expCmp;
      }
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is VaultDocument &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.category == category &&
        other.physicalLocation == physicalLocation &&
        other.notes == notes &&
        other.issueDate == issueDate &&
        other.expirationDate == expirationDate;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    category,
    physicalLocation,
    notes,
    issueDate,
    expirationDate,
  );

  /// Redacts sensitive document metadata so private contents never appear in logs.
  @override
  String toString() =>
      'VaultDocument(id: $id, category: ${category.dbValue}, title: [REDACTED], location: [REDACTED], notes: [REDACTED])';
}
