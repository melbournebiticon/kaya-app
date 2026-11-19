import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/reminders/application/reminder_controller.dart';
import 'package:kaya/features/reminders/domain/reminder_item.dart';
import 'package:kaya/features/reminders/presentation/reminder_form_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Displays an individual [ReminderItem] with confirmed Complete/Reopen
/// safeguard, Undo SnackBar, Edit, and Confirmed Delete controls.
class ReminderCardTile extends StatelessWidget {
  const ReminderCardTile({
    super.key,
    required this.reminder,
    required this.controller,
  });

  final ReminderItem reminder;
  final ReminderController controller;

  Future<void> _handleDelete(BuildContext context) async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Delete Reminder?',
      message:
          'Are you sure you want to delete "${reminder.title}"? This action cannot be undone.',
      confirmLabel: 'Delete Reminder',
    );
    if (confirmed) {
      await controller.deleteReminder(reminder.id);
    }
  }

  Future<void> _handleToggleCompletion(
    BuildContext context,
    ReminderDueBucket bucket,
  ) async {
    final bool nextCompleted = !reminder.isCompleted;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );

    final String title;
    final String message;
    final String confirmLabel;

    if (nextCompleted && bucket == ReminderDueBucket.upcoming) {
      title = 'Complete Upcoming Reminder Early?';
      message =
          '"${reminder.title}" is scheduled for ${reminder.dueDate.formatReadable()} (${reminder.dueStatusLabel(controller.referenceToday)}). Are you sure you want to complete it early?';
      confirmLabel = 'Complete Early';
    } else if (nextCompleted) {
      title = 'Complete Reminder?';
      message = 'Mark "${reminder.title}" as completed?';
      confirmLabel = 'Mark Completed';
    } else {
      title = 'Reopen Reminder?';
      message = 'Return "${reminder.title}" to active reminders?';
      confirmLabel = 'Reopen Reminder';
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

    final bool updated = await controller.setReminderCompleted(
      reminderId: reminder.id,
      isCompleted: nextCompleted,
    );
    if (updated && messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nextCompleted
                ? 'Completed reminder "${reminder.title}".'
                : 'Reopened reminder "${reminder.title}".',
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.primary,
            onPressed: () {
              controller.setReminderCompleted(
                reminderId: reminder.id,
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
    final ReminderDueBucket bucket = reminder.dueBucket(today);

    final Color dueColor = reminder.isCompleted
        ? AppColors.success
        : switch (bucket) {
            ReminderDueBucket.overdue => AppColors.error,
            ReminderDueBucket.today => AppColors.warning,
            ReminderDueBucket.upcoming => AppColors.info,
          };

    return KayaCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      highlighted: !reminder.isCompleted && bucket == ReminderDueBucket.overdue,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            key: ValueKey<String>('reminder_toggle_${reminder.id}'),
            tooltip: reminder.isCompleted
                ? 'Reopen reminder'
                : 'Complete reminder',
            onPressed: controller.isMutating
                ? null
                : () => _handleToggleCompletion(context, bucket),
            icon: Icon(
              reminder.isCompleted
                  ? Icons.check_circle
                  : Icons.notifications_active_outlined,
              color: reminder.isCompleted
                  ? AppColors.success
                  : AppColors.secondary,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    reminder.title,
                    style: textTheme.titleMedium?.copyWith(
                      decoration: reminder.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: reminder.isCompleted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            reminder.isCompleted
                                ? Icons.check_circle_outline
                                : Icons.event_outlined,
                            size: 14,
                            color: dueColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reminder.dueStatusLabel(today),
                            style: textTheme.bodySmall?.copyWith(
                              color: dueColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '• ${reminder.dueDate.formatReadable()}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (reminder.notes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(reminder.notes, style: textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey<String>('reminder_edit_${reminder.id}'),
            tooltip: 'Edit reminder',
            icon: const Icon(
              Icons.edit_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            onPressed: controller.isMutating
                ? null
                : () => ReminderFormDialog.show(
                    context,
                    controller: controller,
                    existingReminder: reminder,
                  ),
          ),
          IconButton(
            key: ValueKey<String>('reminder_delete_${reminder.id}'),
            tooltip: 'Delete reminder',
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
