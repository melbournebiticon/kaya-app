import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/life_vault_validators.dart';
import 'package:kaya/features/life_vault/domain/belonging_item.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/life_vault/domain/life_vault_repository.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';

/// Deterministic, RLS-enforcing implementation of [LifeVaultRepository].
class InMemoryLifeVaultRepository implements LifeVaultRepository {
  InMemoryLifeVaultRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, VaultDocument> _documentsById = <String, VaultDocument>{};
  final Map<String, BelongingItem> _belongingsById = <String, BelongingItem>{};
  int _nextDocSeq = 1;
  int _nextBelongingSeq = 1;

  /// Test hook to simulate network errors and verify error/retry states.
  bool simulateNetworkFailure = false;

  void _checkNetwork() {
    if (simulateNetworkFailure) {
      throw AuthFailure.network(
        'Unable to synchronize Life Vault records. Please check your connection and try again.',
      );
    }
  }

  String _requireAuthenticatedUser(String authenticatedUserId) {
    final String trimmed = authenticatedUserId.trim();
    if (trimmed.isEmpty) {
      throw AuthFailure.unauthorizedAccess();
    }
    return trimmed;
  }

  VaultDocument _requireOwnedDocument({
    required String authenticatedUserId,
    required String documentId,
  }) {
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final VaultDocument? existing = _documentsById[documentId.trim()];
    if (existing == null || existing.userId != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return existing;
  }

  BelongingItem _requireOwnedBelonging({
    required String authenticatedUserId,
    required String belongingId,
  }) {
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    final BelongingItem? existing = _belongingsById[belongingId.trim()];
    if (existing == null || existing.userId != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return existing;
  }

  void _validateDocumentPayload({
    required String title,
    required String physicalLocation,
    required String notes,
    required KayaDateOnly? issueDate,
    required KayaDateOnly? expirationDate,
  }) {
    final String? titleError = LifeVaultValidators.validateRequiredText(
      title,
      fieldName: 'Document name',
    );
    if (titleError != null) {
      throw AuthFailure.validation(titleError);
    }
    final String? locError = LifeVaultValidators.validateRequiredText(
      physicalLocation,
      fieldName: 'Physical location',
    );
    if (locError != null) {
      throw AuthFailure.validation(locError);
    }
    final String? notesError = LifeVaultValidators.validateNotes(notes);
    if (notesError != null) {
      throw AuthFailure.validation(notesError);
    }
    final String? datesError = LifeVaultValidators.validateDocumentDates(
      issueDate: issueDate,
      expirationDate: expirationDate,
    );
    if (datesError != null) {
      throw AuthFailure.validation(datesError);
    }
  }

  void _validateBelongingPayload({
    required String title,
    required String storageLocation,
    required String notes,
    required BelongingCustodyType custodyType,
    required String counterpartyName,
    required KayaDateOnly? dueReturnDate,
  }) {
    final String? titleError = LifeVaultValidators.validateRequiredText(
      title,
      fieldName: 'Item name',
    );
    if (titleError != null) {
      throw AuthFailure.validation(titleError);
    }
    final String? locError = LifeVaultValidators.validateRequiredText(
      storageLocation,
      fieldName: 'Storage location',
    );
    if (locError != null) {
      throw AuthFailure.validation(locError);
    }
    final String? notesError = LifeVaultValidators.validateNotes(notes);
    if (notesError != null) {
      throw AuthFailure.validation(notesError);
    }
    final String? partyError = LifeVaultValidators.validateCounterparty(
      requiresCounterparty: custodyType.requiresCounterparty,
      counterpartyName: counterpartyName,
    );
    if (partyError != null) {
      throw AuthFailure.validation(partyError);
    }
    final String? returnDateError = LifeVaultValidators.validateDueReturnDate(
      dueReturnDate,
    );
    if (returnDateError != null) {
      throw AuthFailure.validation(returnDateError);
    }
  }

  @override
  Future<List<VaultDocument>> fetchDocuments({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return _documentsById.values
        .where((VaultDocument d) => d.userId == uid)
        .toList();
  }

  @override
  Future<VaultDocument> createDocument({
    required String authenticatedUserId,
    required String title,
    required DocumentCategory category,
    required String physicalLocation,
    String notes = '',
    KayaDateOnly? issueDate,
    KayaDateOnly? expirationDate,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    _validateDocumentPayload(
      title: title,
      physicalLocation: physicalLocation,
      notes: notes,
      issueDate: issueDate,
      expirationDate: expirationDate,
    );

    final DateTime now = _clock().toUtc();
    final String id = 'doc_${_nextDocSeq++}';
    final VaultDocument created = VaultDocument(
      id: id,
      userId: uid,
      title: title.trim(),
      category: category,
      physicalLocation: physicalLocation.trim(),
      notes: notes.trim(),
      issueDate: issueDate,
      expirationDate: expirationDate,
      createdAt: now,
      updatedAt: now,
    );
    _documentsById[id] = created;
    return created;
  }

  @override
  Future<VaultDocument> updateDocument({
    required String authenticatedUserId,
    required String documentId,
    required String title,
    required DocumentCategory category,
    required String physicalLocation,
    required String notes,
    required KayaDateOnly? issueDate,
    required KayaDateOnly? expirationDate,
  }) async {
    _checkNetwork();
    final VaultDocument existing = _requireOwnedDocument(
      authenticatedUserId: authenticatedUserId,
      documentId: documentId,
    );
    _validateDocumentPayload(
      title: title,
      physicalLocation: physicalLocation,
      notes: notes,
      issueDate: issueDate,
      expirationDate: expirationDate,
    );

    final VaultDocument updated = existing.copyWith(
      title: title.trim(),
      category: category,
      physicalLocation: physicalLocation.trim(),
      notes: notes.trim(),
      issueDate: issueDate,
      clearIssueDate: issueDate == null,
      expirationDate: expirationDate,
      clearExpirationDate: expirationDate == null,
      updatedAt: _clock().toUtc(),
    );
    _documentsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<void> deleteDocument({
    required String authenticatedUserId,
    required String documentId,
  }) async {
    _checkNetwork();
    final VaultDocument existing = _requireOwnedDocument(
      authenticatedUserId: authenticatedUserId,
      documentId: documentId,
    );
    _documentsById.remove(existing.id);
  }

  @override
  Future<List<BelongingItem>> fetchBelongings({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    if (requestedOwnerId != null && requestedOwnerId.trim() != uid) {
      throw AuthFailure.unauthorizedAccess();
    }
    return _belongingsById.values
        .where((BelongingItem b) => b.userId == uid)
        .toList();
  }

  @override
  Future<BelongingItem> createBelonging({
    required String authenticatedUserId,
    required String title,
    required BelongingCategory category,
    required String storageLocation,
    String notes = '',
    required BelongingCustodyType custodyType,
    String counterpartyName = '',
    KayaDateOnly? dueReturnDate,
  }) async {
    _checkNetwork();
    final String uid = _requireAuthenticatedUser(authenticatedUserId);
    _validateBelongingPayload(
      title: title,
      storageLocation: storageLocation,
      notes: notes,
      custodyType: custodyType,
      counterpartyName: counterpartyName,
      dueReturnDate: dueReturnDate,
    );

    final DateTime now = _clock().toUtc();
    final String id = 'blg_${_nextBelongingSeq++}';
    final BelongingItem created = BelongingItem(
      id: id,
      userId: uid,
      title: title.trim(),
      category: category,
      storageLocation: storageLocation.trim(),
      notes: notes.trim(),
      custodyType: custodyType,
      counterpartyName: custodyType.requiresCounterparty
          ? counterpartyName.trim()
          : '',
      dueReturnDate: custodyType.requiresCounterparty ? dueReturnDate : null,
      isReturned: false,
      returnedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    _belongingsById[id] = created;
    return created;
  }

  @override
  Future<BelongingItem> updateBelonging({
    required String authenticatedUserId,
    required String belongingId,
    required String title,
    required BelongingCategory category,
    required String storageLocation,
    required String notes,
    required BelongingCustodyType custodyType,
    required String counterpartyName,
    required KayaDateOnly? dueReturnDate,
  }) async {
    _checkNetwork();
    final BelongingItem existing = _requireOwnedBelonging(
      authenticatedUserId: authenticatedUserId,
      belongingId: belongingId,
    );
    _validateBelongingPayload(
      title: title,
      storageLocation: storageLocation,
      notes: notes,
      custodyType: custodyType,
      counterpartyName: counterpartyName,
      dueReturnDate: dueReturnDate,
    );

    final bool isLoan = custodyType.requiresCounterparty;
    final BelongingItem updated = existing.copyWith(
      title: title.trim(),
      category: category,
      storageLocation: storageLocation.trim(),
      notes: notes.trim(),
      custodyType: custodyType,
      counterpartyName: isLoan ? counterpartyName.trim() : '',
      dueReturnDate: isLoan ? dueReturnDate : null,
      clearDueReturnDate: !isLoan || dueReturnDate == null,
      isReturned: isLoan ? existing.isReturned : false,
      clearReturnedAt: !isLoan || !existing.isReturned,
      updatedAt: _clock().toUtc(),
    );
    _belongingsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<BelongingItem> setBelongingReturned({
    required String authenticatedUserId,
    required String belongingId,
    required bool isReturned,
  }) async {
    _checkNetwork();
    final BelongingItem existing = _requireOwnedBelonging(
      authenticatedUserId: authenticatedUserId,
      belongingId: belongingId,
    );
    if (!existing.isLoanItem) {
      throw AuthFailure.validation(
        'Only borrowed or lent items track return status.',
      );
    }

    final DateTime now = _clock().toUtc();
    final BelongingItem updated = existing.copyWith(
      isReturned: isReturned,
      returnedAt: isReturned ? now : null,
      clearReturnedAt: !isReturned,
      updatedAt: now,
    );
    _belongingsById[existing.id] = updated;
    return updated;
  }

  @override
  Future<void> deleteBelonging({
    required String authenticatedUserId,
    required String belongingId,
  }) async {
    _checkNetwork();
    final BelongingItem existing = _requireOwnedBelonging(
      authenticatedUserId: authenticatedUserId,
      belongingId: belongingId,
    );
    _belongingsById.remove(existing.id);
  }
}
