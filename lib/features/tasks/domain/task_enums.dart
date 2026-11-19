import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:material_ui/material_ui.dart';

/// Priority levels for KAYA tasks, ordered from lowest to highest urgency.
enum TaskPriority {
  low(
    id: 'low',
    label: 'Low',
    weight: 1,
    statusType: KayaStatusType.neutral,
    icon: Icons.arrow_downward_outlined,
  ),
  medium(
    id: 'medium',
    label: 'Medium',
    weight: 2,
    statusType: KayaStatusType.info,
    icon: Icons.remove_outlined,
  ),
  high(
    id: 'high',
    label: 'High',
    weight: 3,
    statusType: KayaStatusType.warning,
    icon: Icons.priority_high_outlined,
  ),
  urgent(
    id: 'urgent',
    label: 'Urgent',
    weight: 4,
    statusType: KayaStatusType.critical,
    icon: Icons.local_fire_department_outlined,
  );

  const TaskPriority({
    required this.id,
    required this.label,
    required this.weight,
    required this.statusType,
    required this.icon,
  });

  final String id;
  final String label;
  final int weight;
  final KayaStatusType statusType;
  final IconData icon;

  static TaskPriority? tryFromId(String? rawId) {
    if (rawId == null) {
      return null;
    }
    final String normalized = rawId.trim().toLowerCase();
    for (final TaskPriority p in TaskPriority.values) {
      if (p.id == normalized) {
        return p;
      }
    }
    return null;
  }
}

/// Supported task categories in KAYA.
enum TaskCategory {
  personal(id: 'personal', label: 'Personal', icon: Icons.person_outline),
  work(id: 'work', label: 'Work', icon: Icons.work_outline),
  finance(
    id: 'finance',
    label: 'Finance',
    icon: Icons.account_balance_wallet_outlined,
  ),
  health(id: 'health', label: 'Health', icon: Icons.favorite_border),
  home(id: 'home', label: 'Home', icon: Icons.home_outlined),
  errands(id: 'errands', label: 'Errands', icon: Icons.shopping_bag_outlined),
  other(id: 'other', label: 'Other', icon: Icons.label_outline);

  const TaskCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;

  static TaskCategory? tryFromId(String? rawId) {
    if (rawId == null) {
      return null;
    }
    final String normalized = rawId.trim().toLowerCase();
    for (final TaskCategory c in TaskCategory.values) {
      if (c.id == normalized) {
        return c;
      }
    }
    return null;
  }
}

/// Due date classification relative to a reference `today` calendar date.
enum TaskDueBucket { overdue, today, upcoming, noDueDate }

/// Primary task list filter views in the KAYA Tasks workspace.
enum TaskFilterView {
  all(label: 'All Active'),
  today(label: 'Today'),
  upcoming(label: 'Upcoming'),
  overdue(label: 'Overdue'),
  completed(label: 'Completed');

  const TaskFilterView({required this.label});

  final String label;
}
