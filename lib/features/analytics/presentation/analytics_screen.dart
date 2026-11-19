import 'package:material_ui/material_ui.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/responsive_layout.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';

/// Analytics module foundation screen (Phase 1).
///
/// Follows the design rule: "Don't show fake statistics as real data."
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KayaResponsiveScaffoldBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          KayaSectionHeader(
            title: 'Life & Financial Analytics',
            subtitle: 'Income vs. expenses, budget utilization, task completion, and routine consistency',
          ),
          SizedBox(height: AppSpacing.md),
          KayaEmptyState(
            icon: Icons.insights_outlined,
            title: 'No Analytics Data Available Yet',
            description: 'KAYA only generates charts and progress reports from your verified activity. Add tasks, routines, or financial transactions to unlock historical insights.',
          ),
        ],
      ),
    );
  }
}
