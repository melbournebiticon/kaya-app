import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/data/in_memory_life_vault_repository.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Phase 6 Life Vault UI, Expiring Documents & Loan Return Tests', () {
    testWidgets(
      'creates expiring document and lent-out belonging, surfaces Today alert badge, confirms return with Undo, and deletes document',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(480, 980);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final DateTime fixedNow = DateTime.utc(2026, 11, 16, 10, 0);
        final LifeVaultController vaultCtrl = LifeVaultController(
          repository: InMemoryLifeVaultRepository(clock: () => fixedNow),
          clock: () => fixedNow,
          initialUserId: 'usr_vault_qa',
        );
        await vaultCtrl.loadVault();

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.appShell,
            lifeVaultController: vaultCtrl,
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Life module and open Life Vault sub-tab.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Life'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('life_subtab_vault')),
        );
        await tester.pumpAndSettle();

        // 1. Add an expiring vault document (In 15 Days).
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('vault_add_document_button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('vault_add_document_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('doc_form_title_field')),
          'Philippine Passport',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('doc_form_location_field')),
          'Bedroom Fireproof Safe',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('doc_form_exp_15d_chip')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('doc_form_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Philippine Passport'), findsOneWidget);
        expect(find.text('Expiring in 15 days'), findsOneWidget);

        // 2. Add a lent-out personal belonging.
        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('vault_add_belonging_button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('vault_add_belonging_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('blg_form_custody_lent_out')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('blg_form_title_field')),
          'Bosch Power Drill',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('blg_form_location_field')),
          'Garage Shelf B',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('blg_form_counterparty_field')),
          'Marco Santos',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('blg_form_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bosch Power Drill'), findsOneWidget);
        expect(find.text('Lent to Marco Santos'), findsOneWidget);

        // 3. Switch to Today module -> verify expiring document badge is visible.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Today'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('today_expiring_docs_badge')),
          findsOneWidget,
        );
        expect(find.text('1 expiring doc'), findsOneWidget);

        // 4. Return to Life module, mark Bosch Power Drill as returned (with Undo SnackBar).
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Life'),
          ),
        );
        await tester.pumpAndSettle();

        final String blgId = vaultCtrl.allBelongings.single.id;
        await tester.ensureVisible(
          find.byKey(ValueKey<String>('vault_blg_toggle_returned_$blgId')),
        );
        await tester.tap(
          find.byKey(ValueKey<String>('vault_blg_toggle_returned_$blgId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mark Item as Returned?'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Mark Returned'));
        await tester.pumpAndSettle();

        expect(find.text('Undo'), findsOneWidget);
        expect(vaultCtrl.allBelongings.single.isReturned, isTrue);

        // 5. Delete document with confirmation dialog.
        final String docId = vaultCtrl.allDocuments.single.id;
        await tester.ensureVisible(
          find.byKey(ValueKey<String>('vault_doc_delete_$docId')),
        );
        await tester.tap(
          find.byKey(ValueKey<String>('vault_doc_delete_$docId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Delete Document Record?'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Delete Document'),
        );
        await tester.pumpAndSettle();

        expect(vaultCtrl.allDocuments, isEmpty);
      },
    );
  });
}
