import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/life_vault_validators.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/data/in_memory_life_vault_repository.dart';
import 'package:kaya/features/life_vault/domain/belonging_item.dart';
import 'package:kaya/features/life_vault/domain/life_vault_enums.dart';
import 'package:kaya/features/life_vault/domain/vault_document.dart';

void main() {
  group('LifeVault Expiration Accuracy & Validators', () {
    const KayaDateOnly today = KayaDateOnly(2026, 11, 16);
    final DateTime nowUtc = DateTime.utc(2026, 11, 16, 10, 0);

    VaultDocument makeDoc({KayaDateOnly? exp}) {
      return VaultDocument(
        id: 'doc_test',
        userId: 'usr_a',
        title: 'Secret Passport Title',
        category: DocumentCategory.passportVisa,
        physicalLocation: 'Master Bedroom Safe',
        notes: 'Passport no P1234567A',
        issueDate: const KayaDateOnly(2020, 1, 1),
        expirationDate: exp,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );
    }

    test('classifies expired, expiringSoon (<=30d), valid (>30d), and none accurately', () {
      expect(
        makeDoc(exp: const KayaDateOnly(2026, 11, 15)).expirationStatus(today),
        DocumentExpirationStatus.expired,
      );
      expect(
        makeDoc(exp: const KayaDateOnly(2026, 11, 16)).expirationStatus(today),
        DocumentExpirationStatus.expiringSoon,
      );
      expect(
        makeDoc(exp: const KayaDateOnly(2026, 12, 16)).expirationStatus(today),
        DocumentExpirationStatus.expiringSoon,
      );
      expect(
        makeDoc(exp: const KayaDateOnly(2026, 12, 17)).expirationStatus(today),
        DocumentExpirationStatus.valid,
      );
      expect(
        makeDoc(exp: null).expirationStatus(today),
        DocumentExpirationStatus.noExpiration,
      );
    });

    test(
      'validates issue/expiration ordering and loan counterparty requirements',
      () {
        expect(
          LifeVaultValidators.validateDocumentDates(
            issueDate: const KayaDateOnly(2026, 10, 10),
            expirationDate: const KayaDateOnly(2026, 10, 9),
          ),
          isNotNull,
        );
        expect(
          LifeVaultValidators.validateDocumentDates(
            issueDate: const KayaDateOnly(2026, 10, 10),
            expirationDate: const KayaDateOnly(2026, 10, 10),
          ),
          isNull,
        );
        expect(
          LifeVaultValidators.validateCounterparty(
            requiresCounterparty: true,
            counterpartyName: '   ',
          ),
          isNotNull,
        );
        expect(
          LifeVaultValidators.validateCounterparty(
            requiresCounterparty: true,
            counterpartyName: 'Marco Santos',
          ),
          isNull,
        );
      },
    );

    test(
      'redacts sensitive document and belonging fields in toString logs',
      () {
        final VaultDocument doc = makeDoc(exp: const KayaDateOnly(2027, 5, 1));
        final String docLog = doc.toString();
        expect(docLog, contains('[REDACTED]'));
        expect(docLog, isNot(contains('Secret Passport Title')));
        expect(docLog, isNot(contains('Master Bedroom Safe')));
        expect(docLog, isNot(contains('P1234567A')));

        final BelongingItem item = BelongingItem(
          id: 'blg_1',
          userId: 'usr_a',
          title: 'MacBook Pro Spare',
          category: BelongingCategory.electronics,
          storageLocation: 'Locked Study Drawer',
          notes: 'Serial XYZ998',
          custodyType: BelongingCustodyType.lentOut,
          counterpartyName: 'Elena Cruz',
          dueReturnDate: const KayaDateOnly(2026, 11, 30),
          isReturned: false,
          returnedAt: null,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        );
        final String itemLog = item.toString();
        expect(itemLog, contains('[REDACTED]'));
        expect(itemLog, isNot(contains('MacBook Pro Spare')));
        expect(itemLog, isNot(contains('Locked Study Drawer')));
        expect(itemLog, isNot(contains('Elena Cruz')));
        expect(itemLog, isNot(contains('Serial XYZ998')));
      },
    );
  });

  group('LifeVault RLS Ownership & Logout Cache Isolation', () {
    test(
      'denies cross-account access and wipes private caches on logout',
      () async {
        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 9, 0);
        final InMemoryLifeVaultRepository repo = InMemoryLifeVaultRepository(
          clock: () => fixedNow,
        );

        final VaultDocument userADoc = await repo.createDocument(
          authenticatedUserId: 'usr_a',
          title: 'National ID',
          category: DocumentCategory.governmentId,
          physicalLocation: 'Vault Box 1',
          expirationDate: const KayaDateOnly(2026, 11, 25),
        );
        final BelongingItem userABelonging = await repo.createBelonging(
          authenticatedUserId: 'usr_a',
          title: 'Camera Tripod',
          category: BelongingCategory.electronics,
          storageLocation: 'Closet Shelf',
          custodyType: BelongingCustodyType.lentOut,
          counterpartyName: 'Carlos Reyes',
        );

        // User B cannot fetch, mutate, or delete User A records.
        expect(
          () => repo.fetchDocuments(
            authenticatedUserId: 'usr_b',
            requestedOwnerId: 'usr_a',
          ),
          throwsA(isA<AuthFailure>()),
        );
        expect(
          () => repo.deleteDocument(
            authenticatedUserId: 'usr_b',
            documentId: userADoc.id,
          ),
          throwsA(isA<AuthFailure>()),
        );
        expect(
          () => repo.setBelongingReturned(
            authenticatedUserId: 'usr_b',
            belongingId: userABelonging.id,
            isReturned: true,
          ),
          throwsA(isA<AuthFailure>()),
        );

        final LifeVaultController ctrl = LifeVaultController(
          repository: repo,
          clock: () => fixedNow,
        );
        await ctrl.bindAuthenticatedUser('usr_a');
        expect(ctrl.allDocuments.length, 1);
        expect(ctrl.allBelongings.length, 1);
        expect(ctrl.expiringSoonDocuments.length, 1);

        // Logout immediately wipes cached vault documents & belongings.
        await ctrl.bindAuthenticatedUser(null);
        expect(ctrl.allDocuments, isEmpty);
        expect(ctrl.allBelongings, isEmpty);

        // Switching to User B exposes zero User A records.
        await ctrl.bindAuthenticatedUser('usr_b');
        expect(ctrl.allDocuments, isEmpty);
        expect(ctrl.allBelongings, isEmpty);

        ctrl.dispose();
      },
    );
  });
}
