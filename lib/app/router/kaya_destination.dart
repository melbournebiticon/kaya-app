import 'package:material_ui/material_ui.dart';

/// Core product areas defined in Section 2 of the KAYA Master Blueprint.
enum KayaModule { today, money, life, assistant, analytics, settings }

/// Metadata for each top-level navigation destination in the KAYA App Shell.
class KayaDestination {
  const KayaDestination({
    required this.module,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
  });

  final KayaModule module;
  final String label;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;

  static const List<KayaDestination> all = <KayaDestination>[
    KayaDestination(
      module: KayaModule.today,
      label: 'Today',
      subtitle: 'Daily overview and priorities',
      icon: Icons.wb_sunny_outlined,
      selectedIcon: Icons.wb_sunny,
    ),
    KayaDestination(
      module: KayaModule.money,
      label: 'Money',
      subtitle: 'Income, expenses, budgets & Safe to Spend',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
    KayaDestination(
      module: KayaModule.life,
      label: 'Life',
      subtitle: 'Tasks, bills, documents, routines & belongings',
      icon: Icons.folder_special_outlined,
      selectedIcon: Icons.folder_special,
    ),
    KayaDestination(
      module: KayaModule.assistant,
      label: 'Assistant',
      subtitle: 'Personal assistant grounded in KAYA data',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
    ),
    KayaDestination(
      module: KayaModule.analytics,
      label: 'Analytics',
      subtitle: 'Financial and personal progress',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
    ),
    KayaDestination(
      module: KayaModule.settings,
      label: 'Settings',
      subtitle: 'Account, preferences, privacy & security',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];
}
