import 'package:material_ui/material_ui.dart';
import 'package:kaya/app/router/kaya_destination.dart';
import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/responsive_layout.dart';
import 'package:kaya/features/analytics/presentation/analytics_screen.dart';
import 'package:kaya/features/assistant/application/assistant_controller.dart';
import 'package:kaya/features/assistant/presentation/assistant_screen.dart';
import 'package:kaya/features/auth/application/auth_controller.dart';
import 'package:kaya/features/bills/application/bill_controller.dart';
import 'package:kaya/features/life/presentation/life_screen.dart';
import 'package:kaya/features/life_vault/application/life_vault_controller.dart';
import 'package:kaya/features/money/application/money_controller.dart';
import 'package:kaya/features/money/presentation/money_screen.dart';
import 'package:kaya/features/notifications/application/notification_controller.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/routines/application/life_organization_controller.dart';
import 'package:kaya/features/settings/presentation/settings_screen.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/today/presentation/today_screen.dart';

/// Responsive application shell for KAYA.
///
/// - Uses [NavigationBar] on compact mobile viewports (`< 600px`).
/// - Uses [NavigationRail] on tablet, desktop, and web viewports (`>= 600px`).
/// - Preserves navigation context across modules with [IndexedStack].
class KayaAppShell extends StatefulWidget {
  const KayaAppShell({
    super.key,
    required this.onReplayOnboarding,
    this.initialModule = KayaModule.today,
    this.authController,
    this.taskController,
    this.moneyController,
    this.billController,
    this.reminderController,
    this.lifeVaultController,
    this.lifeOrganizationController,
    this.assistantController,
    this.notificationController,
  });

  final VoidCallback onReplayOnboarding;
  final KayaModule initialModule;
  final AuthController? authController;
  final TaskController? taskController;
  final MoneyController? moneyController;
  final BillController? billController;
  final ReminderController? reminderController;
  final LifeVaultController? lifeVaultController;
  final LifeOrganizationController? lifeOrganizationController;
  final AssistantController? assistantController;
  final NotificationController? notificationController;

  @override
  State<KayaAppShell> createState() => _KayaAppShellState();
}

class _KayaAppShellState extends State<KayaAppShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialModule.index;
  }

  void _selectModule(KayaModule module) {
    setState(() {
      _selectedIndex = module.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool useRail = KayaResponsive.useNavigationRail(width);
    final bool extendedRail = KayaResponsive.useExtendedNavigationRail(width);
    final KayaDestination currentDestination =
        KayaDestination.all[_selectedIndex];
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget moduleStack = IndexedStack(
      index: _selectedIndex,
      children: <Widget>[
        TodayScreen(
          onSelectModule: _selectModule,
          profile: widget.authController?.profile,
          taskController: widget.taskController,
          moneyController: widget.moneyController,
          billController: widget.billController,
          reminderController: widget.reminderController,
          lifeVaultController: widget.lifeVaultController,
          lifeOrganizationController: widget.lifeOrganizationController,
        ),
        MoneyScreen(moneyController: widget.moneyController),
        LifeScreen(
          taskController: widget.taskController,
          billController: widget.billController,
          reminderController: widget.reminderController,
          lifeVaultController: widget.lifeVaultController,
          lifeOrganizationController: widget.lifeOrganizationController,
        ),
        AssistantScreen(assistantController: widget.assistantController),
        const AnalyticsScreen(),
        SettingsScreen(
          onReplayOnboarding: widget.onReplayOnboarding,
          authController: widget.authController,
          notificationController: widget.notificationController,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Text(
              'KAYA',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text('•', style: TextStyle(color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(
                currentDestination.label,
                style: textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: useRail
          ? Row(
              children: <Widget>[
                NavigationRail(
                  extended: extendedRail,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: extendedRail
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: <NavigationRailDestination>[
                    for (final KayaDestination dest in KayaDestination.all)
                      NavigationRailDestination(
                        icon: Icon(dest.icon),
                        selectedIcon: Icon(dest.selectedIcon),
                        label: Text(dest.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: moduleStack),
              ],
            )
          : moduleStack,
      bottomNavigationBar: useRail
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                destinations: <NavigationDestination>[
                  for (final KayaDestination dest in KayaDestination.all)
                    NavigationDestination(
                      icon: Icon(dest.icon),
                      selectedIcon: Icon(dest.selectedIcon),
                      label: dest.label,
                      tooltip: dest.subtitle,
                    ),
                ],
              ),
            ),
    );
  }
}
