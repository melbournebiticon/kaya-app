import 'package:flutter_test/flutter_test.dart';
import 'package:kaya/app/app.dart';
import 'package:kaya/features/auth/application/auth_controller.dart';
import 'package:kaya/features/auth/data/in_memory_auth_profile_repository.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('Phase 2 Authentication & User Profile Widget Tests', () {
    testWidgets(
      'rejects empty/invalid inputs and supports Password Recovery flow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(440, 920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final InMemoryAuthProfileRepository repo =
            InMemoryAuthProfileRepository();
        final AuthController controller = AuthController(repository: repo);

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.auth,
            authController: controller,
            requireAuthentication: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome Back to KAYA'), findsOneWidget);

        // Submit empty Sign In form -> field-level validation errors appear
        await tester.tap(
          find.byKey(const ValueKey<String>('auth_submit_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Email address is required.'), findsOneWidget);
        expect(find.text('Password is required.'), findsOneWidget);

        // Switch to Password Recovery
        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();
        expect(find.text('Recover Your Password'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey<String>('auth_email_field')),
          'recover@kaya.app',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('auth_submit_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('password recovery instructions have been sent'),
          findsOneWidget,
        );
        expect(repo.recoveryRequestedEmails, contains('recover@kaya.app'));
      },
    );

    testWidgets(
      'registers new account, edits profile & currency in Settings, and signs out cleanly',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(440, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final InMemoryAuthProfileRepository repo =
            InMemoryAuthProfileRepository();
        final AuthController controller = AuthController(repository: repo);

        await tester.pumpWidget(
          KayaApp(
            initialStage: KayaEntryStage.auth,
            authController: controller,
            requireAuthentication: true,
          ),
        );
        await tester.pumpAndSettle();

        // Switch from Sign In to Create Account
        await tester.tap(
          find.byKey(const ValueKey<String>('switch_to_register_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Create Your KAYA Account'), findsOneWidget);

        // Fill registration fields
        await tester.enterText(
          find.byKey(const ValueKey<String>('auth_display_name_field')),
          'Elena Gomez',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('auth_email_field')),
          'elena@kaya.app',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('auth_password_field')),
          'StrongPass123',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('auth_confirm_password_field')),
          'StrongPass123',
        );

        await tester.ensureVisible(
          find.byKey(const ValueKey<String>('auth_submit_button')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('auth_submit_button')),
        );
        await tester.pumpAndSettle();

        // Verify transition into AppShell with personalized badge
        expect(find.text('Today Overview'), findsOneWidget);
        expect(find.text('Elena Gomez • PHP'), findsOneWidget);

        // Open Settings tab
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Settings'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Elena Gomez'), findsOneWidget);
        expect(find.text('elena@kaya.app'), findsOneWidget);
        expect(find.text('Currency: PHP (₱)'), findsOneWidget);

        // Edit Profile & Currency
        await tester.tap(
          find.byKey(const ValueKey<String>('profile_edit_button')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('profile_edit_display_name')),
          'Elena G. Rivera',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('profile_save_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Elena G. Rivera'), findsOneWidget);
        expect(
          find.text('Profile and currency preferences saved.'),
          findsOneWidget,
        );

        // Sign Out with confirmation dialog
        await tester.tap(
          find.byKey(const ValueKey<String>('profile_logout_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sign Out of KAYA?'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out').last);
        await tester.pumpAndSettle();

        // Verify return to Sign In screen and private state cleared
        expect(find.text('Welcome Back to KAYA'), findsOneWidget);
        expect(controller.isAuthenticated, isFalse);
        expect(controller.profile, isNull);
      },
    );
  });
}
