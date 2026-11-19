import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:kaya/features/tasks/domain/task_item.dart';
import 'package:kaya/features/tasks/presentation/task_form_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Displays an individual [TaskItem] with complete/reopen, edit, and confirmed
/// delete controls.
class TaskCardTile extends StatelessWidget {
  const TaskCardTile({super.key, required this.task, required this.controller});

  final TaskItem task;
  final TaskController controller;

  Future<void> _handleDelete(BuildContext context) async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Delete Task?',
      message:
          'Are you sure you want to delete "${task.title}"? This action cannot be undone.',
      confirmLabel: 'Delete Task',
    );
    if (confirmed) {
      await controller.deleteTask(task.id);
    }
  }

  Future<void> _handleToggleCompletion(
    BuildContext context,
    TaskDueBucket bucket,
  ) async {
    final bool nextCompleted = !task.isCompleted;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );

    final String title;
    final String message;
    final String confirmLabel;

    if (nextCompleted && bucket == TaskDueBucket.upcoming) {
      title = 'Complete Upcoming Task Early?';
      message =
          '"${task.title}" is scheduled for ${task.dueDate!.formatReadable()} (${task.dueStatusLabel(controller.referenceToday)}). Are you sure you want to mark it as completed early?';
      confirmLabel = 'Complete Early';
    } else if (nextCompleted) {
      title = 'Complete Task?';
      message = 'Mark "${task.title}" as completed?';
      confirmLabel = 'Mark Completed';
    } else {
      title = 'Reopen Task?';
      message = 'Move "${task.title}" back to your active tasks?';
      confirmLabel = 'Reopen Task';
    }

    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      isDestructive: false,
    );
    if (!confirmed) {
      return;
    }

    final bool updated = await controller.setTaskCompleted(
      taskId: task.id,
      isCompleted: nextCompleted,
    );
    if (updated && messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nextCompleted
                ? 'Completed "${task.title}".'
                : 'Reopened "${task.title}".',
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primary,
            onPressed: () {
              controller.setTaskCompleted(
                taskId: task.id,
                isCompleted: !nextCompleted,
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final KayaDateOnly today = controller.referenceToday;
    final TaskDueBucket bucket = task.dueBucket(today);

    final Color dueColor = task.isCompleted
        ? AppColors.success
        : switch (bucket) {
            TaskDueBucket.overdue => AppColors.error,
            TaskDueBucket.today => AppColors.warning,
            TaskDueBucket.upcoming => AppColors.info,
            TaskDueBucket.noDueDate => AppColors.textMuted,
          };

    final IconData dueIcon = task.isCompleted
        ? Icons.check_circle_outline
        : switch (bucket) {
            TaskDueBucket.overdue => Icons.warning_amber_outlined,
            TaskDueBucket.today => Icons.today_outlined,
            TaskDueBucket.upcoming => Icons.event_outlined,
            TaskDueBucket.noDueDate => Icons.event_busy_outlined,
          };

    final Color priorityColor = switch (task.priority) {
      TaskPriority.urgent => AppColors.error,
      TaskPriority.high => AppColors.warning,
      TaskPriority.medium => AppColors.info,
      TaskPriority.low => AppColors.textSecondary,
    };

    return KayaCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      highlighted: !task.isCompleted && bucket == TaskDueBucket.overdue,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            checked: task.isCompleted,
            label: task.isCompleted
                ? 'Reopen task ${task.title}'
                : 'Complete task ${task.title}',
            child: IconButton(
              key: ValueKey<String>('task_toggle_${task.id}'),
              tooltip: task.isCompleted ? 'Reopen task' : 'Complete task',
              icon: Icon(
                task.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: task.isCompleted
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              onPressed: controller.isMutating
                  ? null
                  : () => _handleToggleCompletion(context, bucket),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    task.title,
                    style: textTheme.titleMedium?.copyWith(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (task.notes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      task.notes,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _InlineMetaItem(
                        icon: dueIcon,
                        color: dueColor,
                        label: task.isCompleted
                            ? 'Completed'
                            : task.dueStatusLabel(today),
                      ),
                      if (task.priority != TaskPriority.medium)
                        _InlineMetaItem(
                          icon: task.priority.icon,
                          color: priorityColor,
                          label: task.priority.label,
                        ),
                      _InlineMetaItem(
                        icon: task.category.icon,
                        color: AppColors.textMuted,
                        label: task.category.label,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey<String>('task_edit_${task.id}'),
            tooltip: 'Edit task',
            icon: const Icon(
              Icons.edit_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            onPressed: controller.isMutating
                ? null
                : () => TaskFormDialog.show(
                    context,
                    controller: controller,
                    existingTask: task,
                  ),
          ),
          IconButton(
            key: ValueKey<String>('task_delete_${task.id}'),
            tooltip: 'Delete task',
            icon: const Icon(
              Icons.delete_outline,
              size: 19,
              color: AppColors.textMuted,
            ),
            onPressed: controller.isMutating
                ? null
                : () => _handleDelete(context),
          ),
        ],
      ),
    );
  }
}

class _InlineMetaItem extends StatelessWidget {
  const _InlineMetaItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
