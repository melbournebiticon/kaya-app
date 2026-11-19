import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/app/theme/app_theme.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('KayaButton Widget Tests', () {
    testWidgets('executes onPressed and enforces 48px minimum height', (
      WidgetTester tester,
    ) async {
      int tapCount = 0;

      await tester.pumpWidget(
        _wrapWithTheme(
          KayaButton(label: 'Save Entry', onPressed: () => tapCount++),
        ),
      );

      final Size buttonSize = tester.getSize(find.byType(KayaButton));
      expect(
        buttonSize.height,
        greaterThanOrEqualTo(AppSpacing.minTouchTarget),
      );

      await tester.tap(find.text('Save Entry'));
      await tester.pump();
      expect(tapCount, 1);
    });

    testWidgets('prevents duplicate taps when isLoading is true', (
      WidgetTester tester,
    ) async {
      int tapCount = 0;

      await tester.pumpWidget(
        _wrapWithTheme(
          KayaButton(
            label: 'Submitting',
            isLoading: true,
            onPressed: () => tapCount++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Submitting'));
      await tester.pump();
      expect(tapCount, 0);
    });
  });

  group('KayaStatusBadge Accessibility Tests', () {
    testWidgets('renders both an icon and a text label (not color alone)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const KayaStatusBadge(
            label: 'Due Soon',
            type: KayaStatusType.warning,
          ),
        ),
      );

      expect(find.text('Due Soon'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
    });
  });

  group('KAYA State Views & Destructive Confirmation', () {
    testWidgets('KayaEmptyState renders message and optional action', (
      WidgetTester tester,
    ) async {
      bool actionCalled = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          KayaEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing Here Yet',
            description: 'Add your first item to get started.',
            actionLabel: 'Create Item',
            onAction: () => actionCalled = true,
          ),
        ),
      );

      expect(find.text('Nothing Here Yet'), findsOneWidget);
      await tester.tap(find.text('Create Item'));
      await tester.pump();
      expect(actionCalled, isTrue);
    });

    testWidgets('KayaErrorState renders message and triggers retry callback', (
      WidgetTester tester,
    ) async {
      int retries = 0;

      await tester.pumpWidget(
        _wrapWithTheme(
          KayaErrorState(
            title: 'Connection Failed',
            message: 'Unable to fetch records.',
            onRetry: () => retries++,
          ),
        ),
      );

      expect(find.text('Connection Failed'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets(
      'KayaConfirmDialog returns false on cancel and true on confirm',
      (WidgetTester tester) async {
        bool? dialogResult;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: KayaButton(
                    label: 'Delete Item',
                    onPressed: () async {
                      dialogResult = await KayaConfirmDialog.show(
                        context,
                        title: 'Delete Item?',
                        message: 'This action cannot be undone.',
                        confirmLabel: 'Delete',
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Delete Item'));
        await tester.pumpAndSettle();
        expect(find.text('Delete Item?'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(dialogResult, isFalse);

        await tester.tap(find.text('Delete Item'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(dialogResult, isTrue);
      },
    );
  });
}
