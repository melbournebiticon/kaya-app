import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';

void main() {
  group('KAYA Splash, Onboarding, and App Shell Navigation', () {
    testWidgets(
      'transitions from Splash to Onboarding and walks through all 4 steps to AppShell',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const KayaApp(
            initialStage: KayaEntryStage.splash,
            splashDuration: Duration(milliseconds: 300),
          ),
        );

        // Verify Splash Screen
        expect(find.text('YOUR LIFE, CLEARER.'), findsOneWidget);
        expect(find.text('Initializing personal workspace'), findsOneWidget);

        // Advance past splash timer
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Step 1 of 4
        expect(find.text('Step 1 of 4'), findsOneWidget);
        expect(find.text('Your Life, Clearer.'), findsOneWidget);

        // Step 2 of 4
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Step 2 of 4'), findsOneWidget);
        expect(
          find.text('Stay Ahead of Tasks, Bills & Documents'),
          findsOneWidget,
        );

        // Test Back button returns to Step 1
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Step 1 of 4'), findsOneWidget);

        // Advance to Step 4
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Step 3 of 4'), findsOneWidget);

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Step 4 of 4'), findsOneWidget);
        expect(find.text('Ask KAYA in English or Taglish'), findsOneWidget);

        // Complete Onboarding
        await tester.tap(find.text('Enter KAYA'));
        await tester.pumpAndSettle();

        // Verify AppShell Today module is active
        expect(find.text('Today Overview'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets('navigates across all 6 core modules and preserves state', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const KayaApp(initialStage: KayaEntryStage.appShell),
      );
      await tester.pumpAndSettle();

      // 1. Today
      expect(find.text('Today Overview'), findsOneWidget);

      // 2. Money
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Money'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Safe to Spend'), findsOneWidget);

      // 3. Life (Tasks sub-tab + All Areas sub-tab)
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Life'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Task Management'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('life_subtab_domains')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Life Domains'), findsOneWidget);

      // 4. Assistant
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Assistant'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('KAYA Smart Assistant'), findsOneWidget);

      // 5. Analytics
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Analytics'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Life & Financial Analytics'), findsOneWidget);

      // 6. Settings & UI State Inspector
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Settings'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Settings & Preferences'), findsOneWidget);

      // Test Error State & Retry in Settings Inspector
      await tester.ensureVisible(find.text('Preview Error'));
      await tester.tap(find.text('Preview Error'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Reach Server'), findsOneWidget);

      await tester.ensureVisible(find.text('Try Again'));
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Ready State Active'), findsOneWidget);
    });

    testWidgets(
      'adapts layout to NavigationRail on desktop and wide web viewports (>= 600px)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const KayaApp(initialStage: KayaEntryStage.appShell),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );
  });
}
