/// Supported important document categories in Life Vault (Phase 6).
enum DocumentCategory {
  governmentId(dbValue: 'government_id', label: 'Government ID'),
  passportVisa(dbValue: 'passport_visa', label: 'Passport & Visa'),
  financialTax(dbValue: 'financial_tax', label: 'Financial & Tax'),
  insuranceMedical(dbValue: 'insurance_medical', label: 'Insurance & Medical'),
  propertyVehicle(
    dbValue: 'property_vehicle',
    label: 'Property & Vehicle Deed',
  ),
  warrantyContract(
    dbValue: 'warranty_contract',
    label: 'Warranties & Contracts',
  ),
  educationCertificate(
    dbValue: 'education_certificate',
    label: 'School & Certificates',
  ),
  other(dbValue: 'other', label: 'Other Documents');

  const DocumentCategory({required this.dbValue, required this.label});

  final String dbValue;
  final String label;

  static DocumentCategory? tryFromDbValue(String? raw) {
    if (raw == null) {
      return null;
    }
    final String normalized = raw.trim().toLowerCase();
    for (final DocumentCategory value in DocumentCategory.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// Accurate calendar expiration classification relative to reference today.
enum DocumentExpirationStatus {
  expired(label: 'Expired'),
  expiringSoon(label: 'Expiring Soon'),
  valid(label: 'Valid'),
  noExpiration(label: 'No Expiration');

  const DocumentExpirationStatus({required this.label});

  final String label;
}

/// Filter tabs for Life Vault documents.
enum DocumentFilterView {
  all(label: 'All'),
  expiringSoon(label: 'Expiring Soon'),
  expired(label: 'Expired'),
  valid(label: 'Valid');

  const DocumentFilterView({required this.label});

  final String label;
}

/// Supported personal belonging categories in Life Vault (Phase 6).
enum BelongingCategory {
  electronics(dbValue: 'electronics', label: 'Electronics & Tech'),
  toolsEquipment(dbValue: 'tools_equipment', label: 'Tools & Equipment'),
  booksMedia(dbValue: 'books_media', label: 'Books & Media'),
  documentsCards(dbValue: 'documents_cards', label: 'Keys, Cards & Folders'),
  apparelAccessories(
    dbValue: 'apparel_accessories',
    label: 'Apparel & Accessories',
  ),
  homeKitchen(dbValue: 'home_kitchen', label: 'Home & Kitchen'),
  valuables(dbValue: 'valuables', label: 'Valuables & Keepsakes'),
  other(dbValue: 'other', label: 'Other Belongings');

  const BelongingCategory({required this.dbValue, required this.label});

  final String dbValue;
  final String label;

  static BelongingCategory? tryFromDbValue(String? raw) {
    if (raw == null) {
      return null;
    }
    final String normalized = raw.trim().toLowerCase();
    for (final BelongingCategory value in BelongingCategory.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// Custody direction for personal belongings and borrowed/lent tracking.
enum BelongingCustodyType {
  owned(dbValue: 'owned', label: 'In My Possession'),
  lentOut(dbValue: 'lent_out', label: 'Lent Out'),
  borrowed(dbValue: 'borrowed', label: 'Borrowed');

  const BelongingCustodyType({required this.dbValue, required this.label});

  final String dbValue;
  final String label;

  bool get requiresCounterparty => this != BelongingCustodyType.owned;

  static BelongingCustodyType? tryFromDbValue(String? raw) {
    if (raw == null) {
      return null;
    }
    final String normalized = raw.trim().toLowerCase();
    for (final BelongingCustodyType value in BelongingCustodyType.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return null;
  }
}

/// Filter tabs for Life Vault personal belongings and borrowed/lent items.
enum BelongingFilterView {
  all(label: 'All'),
  owned(label: 'Owned'),
  lentOut(label: 'Lent Out'),
  borrowed(label: 'Borrowed'),
  returned(label: 'Returned');

  const BelongingFilterView({required this.label});

  final String label;
}
