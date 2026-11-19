import 'package:material_ui/material_ui.dart';
import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';

/// Supported visual variants for [KayaButton].
enum KayaButtonVariant { primary, secondary, outline, ghost, destructive }

/// Reusable, accessible button component following KAYA Design System tokens.
///
/// - Enforces at least [AppSpacing.minTouchTarget] (48px) height.
/// - Guards against duplicate submissions when [isLoading] is `true`.
class KayaButton extends StatelessWidget {
  const KayaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = KayaButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final KayaButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? effectiveOnPressed = isLoading ? null : onPressed;
    final (_ButtonPalette palette, BorderSide? border) = _resolveStyle(variant);

    final Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (isLoading) ...<Widget>[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(palette.foreground),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ] else if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: palette.foreground),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: effectiveOnPressed == null && !isLoading
                  ? AppColors.textMuted
                  : palette.foreground,
            ),
          ),
        ),
      ],
    );

    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: palette.background,
      foregroundColor: palette.foreground,
      disabledBackgroundColor: isLoading
          ? palette.background.withValues(alpha: 0.75)
          : AppColors.surfaceSubtle,
      disabledForegroundColor: AppColors.textMuted,
      elevation: 0,
      shadowColor: Colors.transparent,
      minimumSize: Size(
        fullWidth ? double.infinity : 64,
        AppSpacing.minTouchTarget,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: border ?? BorderSide.none,
      ),
    );

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      label: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        child: ElevatedButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: content,
        ),
      ),
    );
  }

  (_ButtonPalette, BorderSide?) _resolveStyle(KayaButtonVariant variant) {
    switch (variant) {
      case KayaButtonVariant.primary:
        return (
          const _ButtonPalette(
            background: AppColors.primary,
            foreground: AppColors.onPrimary,
          ),
          null,
        );
      case KayaButtonVariant.secondary:
        return (
          const _ButtonPalette(
            background: AppColors.secondaryContainer,
            foreground: AppColors.secondary,
          ),
          const BorderSide(color: AppColors.border),
        );
      case KayaButtonVariant.outline:
        return (
          const _ButtonPalette(
            background: AppColors.surface,
            foreground: AppColors.textPrimary,
          ),
          const BorderSide(color: AppColors.border),
        );
      case KayaButtonVariant.ghost:
        return (
          const _ButtonPalette(
            background: Colors.transparent,
            foreground: AppColors.textSecondary,
          ),
          null,
        );
      case KayaButtonVariant.destructive:
        return (
          const _ButtonPalette(
            background: AppColors.errorSurface,
            foreground: AppColors.error,
          ),
          const BorderSide(color: AppColors.error),
        );
    }
  }
}

class _ButtonPalette {
  const _ButtonPalette({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
