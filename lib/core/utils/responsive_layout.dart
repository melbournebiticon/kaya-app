import 'package:material_ui/material_ui.dart';
import 'package:kaya/app/theme/app_spacing.dart';

/// Responsive viewport categories for Android, Tablet, Web, and Desktop.
enum KayaBreakpoint {
  /// Phones and narrow viewports (< 600px).
  compact,

  /// Tablets and medium windows (600px - 1023px).
  medium,

  /// Desktops and wide web viewports (>= 1024px).
  expanded,
}

/// Centralized responsive breakpoint helpers for KAYA layouts.
abstract final class KayaResponsive {
  static const double mediumWidthThreshold = 600.0;
  static const double expandedWidthThreshold = 1024.0;

  static KayaBreakpoint breakpointForWidth(double width) {
    if (width >= expandedWidthThreshold) {
      return KayaBreakpoint.expanded;
    }
    if (width >= mediumWidthThreshold) {
      return KayaBreakpoint.medium;
    }
    return KayaBreakpoint.compact;
  }

  static KayaBreakpoint of(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return breakpointForWidth(width);
  }

  static bool useNavigationRail(double width) => width >= mediumWidthThreshold;

  static bool useExtendedNavigationRail(double width) =>
      width >= expandedWidthThreshold;

  static int gridColumnsForWidth(double width) {
    final KayaBreakpoint bp = breakpointForWidth(width);
    switch (bp) {
      case KayaBreakpoint.compact:
        return 1;
      case KayaBreakpoint.medium:
        return 2;
      case KayaBreakpoint.expanded:
        return 3;
    }
  }

  static EdgeInsets pagePaddingForWidth(double width) {
    final KayaBreakpoint bp = breakpointForWidth(width);
    switch (bp) {
      case KayaBreakpoint.compact:
        return AppSpacing.pagePaddingCompact;
      case KayaBreakpoint.medium:
        return AppSpacing.pagePaddingMedium;
      case KayaBreakpoint.expanded:
        return AppSpacing.pagePaddingExpanded;
    }
  }
}

/// Centers content within [AppSpacing.maxContentWidth] and applies responsive
/// padding based on viewport width.
class KayaResponsiveScaffoldBody extends StatelessWidget {
  const KayaResponsiveScaffoldBody({
    super.key,
    required this.child,
    this.scrollable = true,
    this.maxWidth = AppSpacing.maxContentWidth,
  });

  final Widget child;
  final bool scrollable;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final EdgeInsets padding = KayaResponsive.pagePaddingForWidth(
          constraints.maxWidth,
        );
        final Widget constrainedContent = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: padding, child: child),
          ),
        );

        if (!scrollable) {
          return constrainedContent;
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: constrainedContent,
        );
      },
    );
  }
}
