import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:kaya/features/notifications/application/notification_controller.dart';
import 'package:kaya/features/notifications/domain/notification_models.dart';
import 'package:material_ui/material_ui.dart';

/// Phase 10 Notification preferences, permission management, quiet hours, and
/// active scheduled alerts card inside [SettingsScreen].
class NotificationsSettingsCard extends StatelessWidget {
  const NotificationsSettingsCard({super.key, required this.controller});

  final NotificationController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final NotificationPreferences prefs = controller.preferences;
    final NotificationPermissionStatus perm = controller.permissionStatus;
    final List<ScheduledKayaNotification> scheduled =
        controller.scheduledNotifications;

    final KayaStatusType permBadgeType = switch (perm) {
      NotificationPermissionStatus.granted => KayaStatusType.positive,
      NotificationPermissionStatus.notDetermined => KayaStatusType.info,
      NotificationPermissionStatus.denied => KayaStatusType.warning,
    };

    return KayaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Text('Notifications & Automation', style: textTheme.titleMedium),
              KayaStatusBadge(label: perm.label, type: permBadgeType),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'KAYA uses local Android notifications only for your upcoming tasks, unpaid bills, expiring documents, and scheduled routines.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (!controller.isPermissionGranted) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: KayaButton(
                key: const ValueKey<String>(
                  'notifications_request_permission_button',
                ),
                label: perm == NotificationPermissionStatus.denied
                    ? 'Retry Permission'
                    : 'Allow Notifications',
                icon: Icons.notifications_active_outlined,
                variant: KayaButtonVariant.secondary,
                onPressed: controller.requestPermission,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          SwitchListTile(
            key: const ValueKey<String>('notifications_master_switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable Notifications'),
            subtitle: const Text('Turn off to cancel all scheduled alerts.'),
            value: prefs.notificationsEnabled,
            onChanged: (bool val) => controller.updatePreferences(
              prefs.copyWith(notificationsEnabled: val),
            ),
          ),
          SwitchListTile(
            key: const ValueKey<String>('notifications_tasks_switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Task & Reminder Alerts'),
            value: prefs.taskRemindersEnabled,
            onChanged: prefs.notificationsEnabled
                ? (bool val) => controller.updatePreferences(
                    prefs.copyWith(taskRemindersEnabled: val),
                  )
                : null,
          ),
          SwitchListTile(
            key: const ValueKey<String>('notifications_bills_switch'),
            contentPadding: EdgeInsets.zero,
            title: Text('Bill Reminders (${prefs.billLeadDays}d before & due)'),
            value: prefs.billRemindersEnabled,
            onChanged: prefs.notificationsEnabled
                ? (bool val) => controller.updatePreferences(
                    prefs.copyWith(billRemindersEnabled: val),
                  )
                : null,
          ),
          SwitchListTile(
            key: const ValueKey<String>('notifications_docs_switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Document Expiration Alerts (${prefs.documentLeadDays}d before)',
            ),
            value: prefs.documentAlertsEnabled,
            onChanged: prefs.notificationsEnabled
                ? (bool val) => controller.updatePreferences(
                    prefs.copyWith(documentAlertsEnabled: val),
                  )
                : null,
          ),
          SwitchListTile(
            key: const ValueKey<String>('notifications_routines_switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Recurring Routine Reminders'),
            value: prefs.routineRemindersEnabled,
            onChanged: prefs.notificationsEnabled
                ? (bool val) => controller.updatePreferences(
                    prefs.copyWith(routineRemindersEnabled: val),
                  )
                : null,
          ),
          SwitchListTile(
            key: const ValueKey<String>('notifications_quiet_hours_switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Quiet Hours'),
            subtitle: Text(
              prefs.quietHours.enabled
                  ? 'Silent window: ${prefs.quietHours.formattedRange} (alerts defer automatically)'
                  : 'Quiet hours disabled',
            ),
            value: prefs.quietHours.enabled,
            onChanged: prefs.notificationsEnabled
                ? (bool val) => controller.updatePreferences(
                    prefs.copyWith(
                      quietHours: prefs.quietHours.copyWith(enabled: val),
                    ),
                  )
                : null,
          ),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            key: const ValueKey<String>('notifications_scheduled_count'),
            scheduled.isEmpty
                ? '0 scheduled alerts active'
                : '${scheduled.length} scheduled alert${scheduled.length == 1 ? '' : 's'} active',
            style: textTheme.labelMedium?.copyWith(
              color: scheduled.isEmpty
                  ? AppColors.textMuted
                  : AppColors.primary,
            ),
          ),
          if (scheduled.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            for (final ScheduledKayaNotification item in scheduled.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  '• ${item.title}: ${item.body}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
