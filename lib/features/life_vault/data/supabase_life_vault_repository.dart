import 'package:kaya/core/data/supabase_error_mapper.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/life_vault_validators.dart';
import 'package:kaya/features/life_vault/domain/belonging_item.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/life_vault/domain/life_vault_repository.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live Supabase implementation of [LifeVaultRepository] (Phase 6).
class SupabaseLifeVaultRepository implements LifeVaultRepository {
  SupabaseLifeVaultRepository({required this.client});

  final SupabaseClient client;

  VaultDocument _docFromRow(Map<String, dynamic> row) {
    return VaultDocument(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      title: (row['title'] as String? ?? '').trim(),
      category:
          DocumentCategory.tryFromDbValue(row['category'] as String?) ??
          DocumentCategory.governmentId,
      physicalLocation: (row['physical_location'] as String? ?? '').trim(),
      notes: (row['notes'] as String? ?? '').trim(),
      issueDate: SupabaseErrorMapper.parseOptionalDateOnly(row['issue_date']),
      expirationDate: SupabaseErrorMapper.parseOptionalDateOnly(
        row['expiration_date'],
      ),
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  BelongingItem _belongingFromRow(Map<String, dynamic> row) {
    return BelongingItem(
      id: (row['id'] as String).trim(),
      userId: (row['user_id'] as String).trim(),
      title: (row['title'] as String? ?? '').trim(),
      category:
          BelongingCategory.tryFromDbValue(row['category'] as String?) ??
          BelongingCategory.electronics,
      storageLocation: (row['storage_location'] as String? ?? '').trim(),
      notes: (row['notes'] as String? ?? '').trim(),
      custodyType:
          BelongingCustodyType.tryFromDbValue(row['custody_type'] as String?) ??
          BelongingCustodyType.owned,
      counterpartyName: (row['counterparty_name'] as String? ?? '').trim(),
      dueReturnDate: SupabaseErrorMapper.parseOptionalDateOnly(
        row['due_return_date'],
      ),
      isReturned: row['is_returned'] as bool? ?? false,
      returnedAt: SupabaseErrorMapper.parseOptionalDateTimeUtc(
        row['returned_at'],
      ),
      createdAt: SupabaseErrorMapper.parseDateTimeUtc(row['created_at']),
      updatedAt: SupabaseErrorMapper.parseDateTimeUtc(row['updated_at']),
    );
  }

  void _validateDocument({
    required String title,
    required String physicalLocation,
    required String notes,
    required KayaDateOnly? issueDate,
    required KayaDateOnly? expirationDate,
  }) {
    final String? tErr = LifeVaultValidators.validateRequiredText(
      title,
      fieldName: 'Document name',
    );
    if (tErr != null) {
      throw AuthFailure.validation(tErr);
    }
    final String? locErr = LifeVaultValidators.validateRequiredText(
      physicalLocation,
      fieldName: 'Physical location',
    );
    if (locErr != null) {
      throw AuthFailure.validation(locErr);
    }
    final String? nErr = LifeVaultValidators.validateNotes(notes);
    if (nErr != null) {
      throw AuthFailure.validation(nErr);
    }
    final String? dErr = LifeVaultValidators.validateDocumentDates(
      issueDate: issueDate,
      expirationDate: expirationDate,
    );
    if (dErr != null) {
      throw AuthFailure.validation(dErr);
    }
  }

  void _validateBelonging({
    required String title,
    required String storageLocation,
    required String notes,
    required BelongingCustodyType custodyType,
    required String counterpartyName,
    required KayaDateOnly? dueReturnDate,
  }) {
    final String? tErr = LifeVaultValidators.validateRequiredText(
      title,
      fieldName: 'Item name',
    );
    if (tErr != null) {
      throw AuthFailure.validation(tErr);
    }
    final String? locErr = LifeVaultValidators.validateRequiredText(
      storageLocation,
      fieldName: 'Storage location',
    );
    if (locErr != null) {
      throw AuthFailure.validation(locErr);
    }
    final String? nErr = LifeVaultValidators.validateNotes(notes);
    if (nErr != null) {
      throw AuthFailure.validation(nErr);
    }
    final String? cErr = LifeVaultValidators.validateCounterparty(
      requiresCounterparty: custodyType.requiresCounterparty,
      counterpartyName: counterpartyName,
    );
    if (cErr != null) {
      throw AuthFailure.validation(cErr);
    }
    final String? rErr = LifeVaultValidators.validateDueReturnDate(
      dueReturnDate,
    );
    if (rErr != null) {
      throw AuthFailure.validation(rErr);
    }
  }

  @override
  Future<List<VaultDocument>> fetchDocuments({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
      requestedOwnerId: requestedOwnerId,
    );
    try {
      final List<dynamic> rows = await client
          .from('vault_documents')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: true);
      return rows
          .map(
            (dynamic row) => _docFromRow(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Unable to load Life Vault documents.');
    }
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
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateDocument(
      title: title,
      physicalLocation: physicalLocation,
      notes: notes,
      issueDate: issueDate,
      expirationDate: expirationDate,
    );
    try {
      final Map<String, dynamic> inserted = await client
          .from('vault_documents')
          .insert(<String, dynamic>{
            'user_id': uid,
            'title': title.trim(),
            'category': category.dbValue,
            'physical_location': physicalLocation.trim(),
            'notes': notes.trim(),
            'issue_date': issueDate?.toIsoDateString(),
            'expiration_date': expirationDate?.toIsoDateString(),
          })
          .select()
          .single();
      return _docFromRow(inserted);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to save document.');
    }
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
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateDocument(
      title: title,
      physicalLocation: physicalLocation,
      notes: notes,
      issueDate: issueDate,
      expirationDate: expirationDate,
    );
    try {
      final Map<String, dynamic> updated = await client
          .from('vault_documents')
          .update(<String, dynamic>{
            'title': title.trim(),
            'category': category.dbValue,
            'physical_location': physicalLocation.trim(),
            'notes': notes.trim(),
            'issue_date': issueDate?.toIsoDateString(),
            'expiration_date': expirationDate?.toIsoDateString(),
          })
          .eq('id', documentId)
          .eq('user_id', uid)
          .select()
          .single();
      return _docFromRow(updated);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update document.');
    }
  }

  @override
  Future<void> deleteDocument({
    required String authenticatedUserId,
    required String documentId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('vault_documents')
          .delete()
          .eq('id', documentId)
          .eq('user_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to delete document.');
    }
  }

  @override
  Future<List<BelongingItem>> fetchBelongings({
    required String authenticatedUserId,
    String? requestedOwnerId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
      requestedOwnerId: requestedOwnerId,
    );
    try {
      final List<dynamic> rows = await client
          .from('personal_belongings')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: true);
      return rows
          .map(
            (dynamic row) =>
                _belongingFromRow(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Unable to load personal belongings.');
    }
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
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateBelonging(
      title: title,
      storageLocation: storageLocation,
      notes: notes,
      custodyType: custodyType,
      counterpartyName: counterpartyName,
      dueReturnDate: dueReturnDate,
    );
    try {
      final Map<String, dynamic> inserted = await client
          .from('personal_belongings')
          .insert(<String, dynamic>{
            'user_id': uid,
            'title': title.trim(),
            'category': category.dbValue,
            'storage_location': storageLocation.trim(),
            'notes': notes.trim(),
            'custody_type': custodyType.dbValue,
            'counterparty_name': custodyType.requiresCounterparty
                ? counterpartyName.trim()
                : '',
            'due_return_date': dueReturnDate?.toIsoDateString(),
          })
          .select()
          .single();
      return _belongingFromRow(inserted);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to save item.');
    }
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
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    _validateBelonging(
      title: title,
      storageLocation: storageLocation,
      notes: notes,
      custodyType: custodyType,
      counterpartyName: counterpartyName,
      dueReturnDate: dueReturnDate,
    );
    try {
      final Map<String, dynamic> updated = await client
          .from('personal_belongings')
          .update(<String, dynamic>{
            'title': title.trim(),
            'category': category.dbValue,
            'storage_location': storageLocation.trim(),
            'notes': notes.trim(),
            'custody_type': custodyType.dbValue,
            'counterparty_name': custodyType.requiresCounterparty
                ? counterpartyName.trim()
                : '',
            'due_return_date': dueReturnDate?.toIsoDateString(),
          })
          .eq('id', belongingId)
          .eq('user_id', uid)
          .select()
          .single();
      return _belongingFromRow(updated);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update item.');
    }
  }

  @override
  Future<BelongingItem> setBelongingReturned({
    required String authenticatedUserId,
    required String belongingId,
    required bool isReturned,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      final Map<String, dynamic> updated = await client
          .from('personal_belongings')
          .update(<String, dynamic>{
            'is_returned': isReturned,
            'returned_at': isReturned
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          })
          .eq('id', belongingId)
          .eq('user_id', uid)
          .select()
          .single();
      return _belongingFromRow(updated);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to update return status.');
    }
  }

  @override
  Future<void> deleteBelonging({
    required String authenticatedUserId,
    required String belongingId,
  }) async {
    final String uid = SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );
    try {
      await client
          .from('personal_belongings')
          .delete()
          .eq('id', belongingId)
          .eq('user_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrestException(e);
    } catch (_) {
      throw AuthFailure.network('Failed to delete item.');
    }
  }
}
