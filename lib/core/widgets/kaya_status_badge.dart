import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:material_ui/material_ui.dart';

/// Semantic status types for [KayaStatusBadge].
enum KayaStatusType { positive, info, warning, critical, neutral }

/// Accessible status indicator that always pairs a semantic icon with a text
/// label so status is never communicated by color alone.
class KayaStatusBadge extends StatelessWidget {
  const KayaStatusBadge({
    super.key,
    required this.label,
    this.type = KayaStatusType.neutral,
    this.customIcon,
  });

  final String label;
  final KayaStatusType type;
  final IconData? customIcon;

  @override
  Widget build(BuildContext context) {
    final (
      Color foreground,
      Color background,
      IconData defaultIcon,
    ) = switch (type) {
      KayaStatusType.positive => (
        AppColors.success,
        AppColors.successSurface,
        Icons.check_circle_outline,
      ),
      KayaStatusType.info => (
        AppColors.info,
        AppColors.infoSurface,
        Icons.info_outline,
      ),
      KayaStatusType.warning => (
        AppColors.warning,
        AppColors.warningSurface,
        Icons.schedule_outlined,
      ),
      KayaStatusType.critical => (
        AppColors.error,
        AppColors.errorSurface,
        Icons.error_outline,
      ),
      KayaStatusType.neutral => (
        AppColors.textSecondary,
        AppColors.surfaceElevated,
        Icons.radio_button_unchecked,
      ),
    };

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + 2,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: foreground.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(customIcon ?? defaultIcon, size: 13, color: foreground),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
