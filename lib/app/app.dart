import 'package:kaya/app/router/app_shell.dart';
import 'package:kaya/app/theme/app_theme.dart';
import 'package:kaya/core/config/supabase_bootstrap.dart';
import 'package:kaya/features/assistant/application/assistant_context_builder.dart';
import 'package:kaya/features/assistant/application/assistant_controller.dart';
import 'package:kaya/features/assistant/data/local_stub_ai_assistant_gateway.dart';
import 'package:kaya/features/auth/application/auth_controller.dart';
import 'package:kaya/features/auth/data/in_memory_auth_profile_repository.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/auth/presentation/auth_screen.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/bills/data/in_memory_bill_repository.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/life_vault/data/in_memory_life_vault_repository.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:kaya/features/notifications/application/notification_controller.dart';
import 'package:kaya/features/notifications/domain/local_notification_gateway.dart';
import 'package:kaya/features/onboarding/presentation/onboarding_screen.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/data/in_memory_reminder_repository.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/routines/data/in_memory_life_organization_repository.dart';
import 'package:kaya/features/splash/presentation/splash_screen.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';
import 'package:material_ui/material_ui.dart';

/// Top-level application flow stages across Phases 1–8.
enum KayaEntryStage { splash, onboarding, auth, appShell }

/// Root widget for the KAYA application.
class KayaApp extends StatefulWidget {
  const KayaApp({
    super.key,
    this.initialStage = KayaEntryStage.splash,
    this.splashDuration = const Duration(milliseconds: 900),
    this.authController,
    this.taskController,
    this.moneyController,
    this.billController,
    this.reminderController,
    this.lifeVaultController,
    this.lifeOrganizationController,
    this.assistantController,
    this.notificationController,
    this.backendRepositories,
    this.requireAuthentication = false,
  });

  final KayaEntryStage initialStage;
  final Duration? splashDuration;
  final AuthController? authController;
  final TaskController? taskController;
  final MoneyController? moneyController;
  final BillController? billController;
  final ReminderController? reminderController;
  final LifeVaultController? lifeVaultController;
  final LifeOrganizationController? lifeOrganizationController;
  final AssistantController? assistantController;
  final NotificationController? notificationController;
  final KayaBackendRepositories? backendRepositories;
  final bool requireAuthentication;

  @override
  State<KayaApp> createState() => _KayaAppState();
}

class _KayaAppState extends State<KayaApp> {
  late KayaEntryStage _stage;
  late AuthController _authController;
  late TaskController _taskController;
  late MoneyController _moneyController;
  late BillController _billController;
  late ReminderController _reminderController;
  late LifeVaultController _lifeVaultController;
  late LifeOrganizationController _lifeOrganizationController;
  late AssistantController _assistantController;
  late NotificationController _notificationController;
  bool _ownsAuthController = false;
  bool _ownsTaskController = false;
  bool _ownsMoneyController = false;
  bool _ownsBillController = false;
  bool _ownsReminderController = false;
  bool _ownsLifeVaultController = false;
  bool _ownsLifeOrganizationController = false;
  bool _ownsAssistantController = false;
  bool _ownsNotificationController = false;

  bool get _enforceAuth =>
      widget.requireAuthentication ||
      widget.authController != null ||
      widget.initialStage == KayaEntryStage.auth;

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage;
    if (widget.authController != null) {
      _authController = widget.authController!;
    } else {
      _authController = AuthController(
        repository:
            widget.backendRepositories?.authRepository ??
            InMemoryAuthProfileRepository(),
      );
      _ownsAuthController = true;
    }

    final String? initialUid = _enforceAuth
        ? _authController.profile?.userId
        : (widget.taskController?.activeUserId ??
              widget.moneyController?.activeUserId ??
              widget.billController?.activeUserId ??
              widget.reminderController?.activeUserId ??
              widget.lifeVaultController?.activeUserId ??
              widget.lifeOrganizationController?.activeUserId ??
              'usr_local_workspace');

    if (widget.taskController != null) {
      _taskController = widget.taskController!;
    } else {
      _taskController = TaskController(
        repository:
            widget.backendRepositories?.taskRepository ??
            InMemoryTaskRepository(),
        initialUserId: initialUid,
      );
      _ownsTaskController = true;
    }

    if (widget.moneyController != null) {
      _moneyController = widget.moneyController!;
    } else {
      _moneyController = MoneyController(
        repository:
            widget.backendRepositories?.moneyRepository ??
            InMemoryMoneyRepository(),
        initialUserId: initialUid,
      );
      _ownsMoneyController = true;
    }

    if (widget.billController != null) {
      _billController = widget.billController!;
    } else {
      _billController = BillController(
        repository:
            widget.backendRepositories?.billRepository ??
            InMemoryBillRepository(),
        initialUserId: initialUid,
      );
      _ownsBillController = true;
    }

    if (widget.reminderController != null) {
      _reminderController = widget.reminderController!;
    } else {
      _reminderController = ReminderController(
        repository:
            widget.backendRepositories?.reminderRepository ??
            InMemoryReminderRepository(),
        initialUserId: initialUid,
      );
      _ownsReminderController = true;
    }

    if (widget.lifeVaultController != null) {
      _lifeVaultController = widget.lifeVaultController!;
    } else {
      _lifeVaultController = LifeVaultController(
        repository:
            widget.backendRepositories?.lifeVaultRepository ??
            InMemoryLifeVaultRepository(),
        initialUserId: initialUid,
      );
      _ownsLifeVaultController = true;
    }

    if (widget.lifeOrganizationController != null) {
      _lifeOrganizationController = widget.lifeOrganizationController!;
    } else {
      _lifeOrganizationController = LifeOrganizationController(
        repository:
            widget.backendRepositories?.lifeOrganizationRepository ??
            InMemoryLifeOrganizationRepository(),
        initialUserId: initialUid,
      );
      _ownsLifeOrganizationController = true;
    }

    _moneyController.bindUnpaidObligationsSource(
      resolver: (int year, int month, SupportedCurrency currency) =>
          _billController.unpaidObligationsMinorForPeriod(
            year: year,
            month: month,
            currency: currency,
          ),
      listenable: _billController,
    );

    if (widget.assistantController != null) {
      _assistantController = widget.assistantController!;
    } else {
      _assistantController = AssistantController(
        contextBuilder: AssistantContextBuilder(
          authController: _authController,
          taskController: _taskController,
          moneyController: _moneyController,
          billController: _billController,
          reminderController: _reminderController,
          lifeVaultController: _lifeVaultController,
          lifeOrganizationController: _lifeOrganizationController,
        ),
        aiGateway:
            widget.backendRepositories?.aiAssistantGateway ??
            LocalStubAiAssistantGateway(),
        initialUserId: initialUid,
        sourceListenables: <Listenable>[
          _authController,
          _taskController,
          _moneyController,
          _billController,
          _reminderController,
          _lifeVaultController,
          _lifeOrganizationController,
        ],
      );
      _ownsAssistantController = true;
    }

    if (widget.notificationController != null) {
      _notificationController = widget.notificationController!;
    } else {
      _notificationController = NotificationController(
        gateway: InMemoryLocalNotificationGateway(),
        taskController: _taskController,
        billController: _billController,
        reminderController: _reminderController,
        lifeVaultController: _lifeVaultController,
        lifeOrganizationController: _lifeOrganizationController,
        initialUserId: initialUid,
      );
      _ownsNotificationController = true;
    }

    _authController.addListener(_handleAuthChanged);
    if (_authController.isAuthenticated) {
      _bindAllModulesToUser(
        _authController.profile?.userId,
        preferredCurrency: _authController.profile?.preferredCurrency,
      );
    }
  }

  @override
  void dispose() {
    _authController.removeListener(_handleAuthChanged);
    if (_ownsAuthController) {
      _authController.dispose();
    }
    if (_ownsTaskController) {
      _taskController.dispose();
    }
    if (_ownsMoneyController) {
      _moneyController.dispose();
    }
    if (_ownsBillController) {
      _billController.dispose();
    }
    if (_ownsReminderController) {
      _reminderController.dispose();
    }
    if (_ownsLifeVaultController) {
      _lifeVaultController.dispose();
    }
    if (_ownsLifeOrganizationController) {
      _lifeOrganizationController.dispose();
    }
    if (_ownsAssistantController) {
      _assistantController.dispose();
    }
    if (_ownsNotificationController) {
      _notificationController.dispose();
    }
    super.dispose();
  }

  Future<void> _bindAllModulesToUser(
    String? uid, {
    SupportedCurrency? preferredCurrency,
  }) async {
    _assistantController.bindAuthenticatedUser(uid);
    await _notificationController.bindAuthenticatedUser(uid);
    await _taskController.bindAuthenticatedUser(uid);
    await _moneyController.bindAuthenticatedUser(
      uid,
      preferredCurrency: preferredCurrency,
    );
    await _billController.bindAuthenticatedUser(
      uid,
      preferredCurrency: preferredCurrency,
    );
    await _reminderController.bindAuthenticatedUser(uid);
    await _lifeVaultController.bindAuthenticatedUser(uid);
    await _lifeOrganizationController.bindAuthenticatedUser(
      uid,
      preferredCurrency: preferredCurrency,
    );
  }

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }
    final String? uid = _authController.isAuthenticated
        ? _authController.profile?.userId
        : null;
    _bindAllModulesToUser(
      uid,
      preferredCurrency: _authController.profile?.preferredCurrency,
    );

    if (!_enforceAuth) {
      return;
    }
    if (_authController.isAuthenticated && _stage == KayaEntryStage.auth) {
      setState(() {
        _stage = KayaEntryStage.appShell;
      });
    } else if (!_authController.isAuthenticated &&
        _stage == KayaEntryStage.appShell) {
      setState(() {
        _stage = KayaEntryStage.auth;
      });
    }
  }

  Future<void> _handleSplashCompleted() async {
    if (_enforceAuth) {
      await _authController.restoreSession();
      if (!mounted) {
        return;
      }
      if (_authController.isAuthenticated) {
        await _bindAllModulesToUser(
          _authController.profile?.userId,
          preferredCurrency: _authController.profile?.preferredCurrency,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _stage = KayaEntryStage.appShell;
        });
        return;
      }
    }
    setState(() {
      _stage = KayaEntryStage.onboarding;
    });
  }

  void _advanceToOnboarding() {
    setState(() {
      _stage = KayaEntryStage.onboarding;
    });
  }

  void _handleOnboardingFinished() {
    setState(() {
      if (_enforceAuth && !_authController.isAuthenticated) {
        _stage = KayaEntryStage.auth;
      } else {
        _stage = KayaEntryStage.appShell;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KAYA — Your Life, Clearer.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: switch (_stage) {
        KayaEntryStage.splash => KayaSplashScreen(
          autoAdvanceDuration: widget.splashDuration,
          onCompleted: _handleSplashCompleted,
        ),
        KayaEntryStage.onboarding => KayaOnboardingScreen(
          onFinished: _handleOnboardingFinished,
        ),
        KayaEntryStage.auth => KayaAuthScreen(
          controller: _authController,
          onReplayOnboarding: _advanceToOnboarding,
        ),
        KayaEntryStage.appShell => KayaAppShell(
          onReplayOnboarding: _advanceToOnboarding,
          authController: _authController,
          taskController: _taskController,
          moneyController: _moneyController,
          billController: _billController,
          reminderController: _reminderController,
          lifeVaultController: _lifeVaultController,
          lifeOrganizationController: _lifeOrganizationController,
          assistantController: _assistantController,
          notificationController: _notificationController,
        ),
      },
    );
  }
}
