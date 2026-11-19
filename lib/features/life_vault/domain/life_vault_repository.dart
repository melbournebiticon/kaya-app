import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/life_vault/domain/belonging_item.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';

/// Repository contract for Phase 6 Life Vault (Documents & Belongings).
///
/// Mirrors PostgreSQL constraints and RLS policies in
/// `supabase/migrations/20261114000005_phase6_life_vault.sql`.
abstract class LifeVaultRepository {
  Future<List<VaultDocument>> fetchDocuments({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  Future<VaultDocument> createDocument({
    required String authenticatedUserId,
    required String title,
    required DocumentCategory category,
    required String physicalLocation,
    String notes = '',
    KayaDateOnly? issueDate,
    KayaDateOnly? expirationDate,
  });

  Future<VaultDocument> updateDocument({
    required String authenticatedUserId,
    required String documentId,
    required String title,
    required DocumentCategory category,
    required String physicalLocation,
    required String notes,
    required KayaDateOnly? issueDate,
    required KayaDateOnly? expirationDate,
  });

  Future<void> deleteDocument({
    required String authenticatedUserId,
    required String documentId,
  });

  Future<List<BelongingItem>> fetchBelongings({
    required String authenticatedUserId,
    String? requestedOwnerId,
  });

  Future<BelongingItem> createBelonging({
    required String authenticatedUserId,
    required String title,
    required BelongingCategory category,
    required String storageLocation,
    String notes = '',
    required BelongingCustodyType custodyType,
    String counterpartyName = '',
    KayaDateOnly? dueReturnDate,
  });

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
  });

  Future<BelongingItem> setBelongingReturned({
    required String authenticatedUserId,
    required String belongingId,
    required bool isReturned,
  });

  Future<void> deleteBelonging({
    required String authenticatedUserId,
    required String belongingId,
  });
}
