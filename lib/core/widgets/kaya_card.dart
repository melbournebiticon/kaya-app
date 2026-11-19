import 'package:material_ui/material_ui.dart';
import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';

/// Reusable surface card container following KAYA Design System tokens.
class KayaCard extends StatelessWidget {
  const KayaCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.highlighted = false,
    this.backgroundColor,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool highlighted;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(
      AppSpacing.radiusLg,
    );
    final Color resolvedBorder =
        borderColor ??
        (highlighted ? AppColors.borderHighlight : AppColors.borderSubtle);

    final Widget cardBody = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: borderRadius,
        border: Border.all(color: resolvedBorder, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: Padding(padding: padding, child: child),
              )
            : Padding(padding: padding, child: child),
      ),
    );

    if (semanticLabel != null) {
      return Semantics(
        container: true,
        button: onTap != null,
        label: semanticLabel,
        child: cardBody,
      );
    }

    return cardBody;
  }
}
