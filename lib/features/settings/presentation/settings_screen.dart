import 'package:material_ui/material_ui.dart';
import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/responsive_layout.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:kaya/features/auth/application/auth_controller.dart';
import 'package:kaya/features/auth/presentation/profile_section_card.dart';

/// Interactive UI state modes for manual QA and automated widget testing.
enum KayaPreviewStateMode { ready, loading, empty, error }

/// Settings module foundation, User Profile controls, & Design System Inspector.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onReplayOnboarding,
    this.authController,
  });

  final VoidCallback onReplayOnboarding;
  final AuthController? authController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  KayaPreviewStateMode _previewMode = KayaPreviewStateMode.ready;
  String? _lastActionFeedback;

  Future<void> _handleDestructiveResetDemo() async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Confirm Destructive Action',
      message: 'KAYA always confirms destructive operations before making changes. Do you want to reset the demo feedback banner?',
      confirmLabel: 'Confirm Reset',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _lastActionFeedback = confirmed
          ? 'Destructive action confirmed by user.'
          : 'Destructive action cancelled safely.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return KayaResponsiveScaffoldBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          KayaSectionHeader(
            title: 'Settings & Preferences',
            subtitle: 'Account, security, and KAYA foundation controls',
            trailing: KayaButton(
              label: 'Replay Onboarding',
              icon: Icons.play_arrow_outlined,
              variant: KayaButtonVariant.outline,
              onPressed: widget.onReplayOnboarding,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.authController != null &&
              widget.authController!.isAuthenticated) ...<Widget>[
            ProfileSectionCard(controller: widget.authController!),
            const SizedBox(height: AppSpacing.md),
          ],
          KayaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Privacy & Data Isolation', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your tasks, transactions, bills, and Life Vault records remain private and tied to your active account.',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const KayaSectionHeader(
            title: 'KAYA Design System & State Inspector',
            subtitle: 'Verify shared tokens, accessible status badges, button variants, and state handling',
          ),
          const SizedBox(height: AppSpacing.sm),
          KayaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Semantic Status Badges', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Every badge pairs a distinct icon with a label so status never relies on color alone.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    KayaStatusBadge(
                      label: 'On Track',
                      type: KayaStatusType.positive,
                    ),
                    KayaStatusBadge(label: 'Synced', type: KayaStatusType.info),
                    KayaStatusBadge(
                      label: 'Due Soon',
                      type: KayaStatusType.warning,
                    ),
                    KayaStatusBadge(
                      label: 'Overdue',
                      type: KayaStatusType.critical,
                    ),
                    KayaStatusBadge(
                      label: 'Draft',
                      type: KayaStatusType.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Button Variants & Destructive Confirmation',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    KayaButton(
                      label: 'Primary Action',
                      icon: Icons.check,
                      onPressed: () {
                        setState(() {
                          _lastActionFeedback = 'Primary action triggered.';
                        });
                      },
                    ),
                    KayaButton(
                      label: 'Secondary',
                      variant: KayaButtonVariant.secondary,
                      onPressed: () {
                        setState(() {
                          _lastActionFeedback = 'Secondary action triggered.';
                        });
                      },
                    ),
                    KayaButton(
                      label: 'Destructive Demo',
                      icon: Icons.delete_outline,
                      variant: KayaButtonVariant.destructive,
                      onPressed: _handleDestructiveResetDemo,
                    ),
                  ],
                ),
                if (_lastActionFeedback != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _lastActionFeedback!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const KayaSectionHeader(
            title: 'UI State Verification (Loading / Empty / Error)',
            subtitle: 'Test how KAYA distinguishes loading, empty data, and recoverable errors',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              KayaButton(
                label: 'Preview Ready',
                variant: _previewMode == KayaPreviewStateMode.ready
                    ? KayaButtonVariant.primary
                    : KayaButtonVariant.outline,
                onPressed: () => setState(() {
                  _previewMode = KayaPreviewStateMode.ready;
                }),
              ),
              KayaButton(
                label: 'Preview Loading',
                variant: _previewMode == KayaPreviewStateMode.loading
                    ? KayaButtonVariant.primary
                    : KayaButtonVariant.outline,
                onPressed: () => setState(() {
                  _previewMode = KayaPreviewStateMode.loading;
                }),
              ),
              KayaButton(
                label: 'Preview Empty',
                variant: _previewMode == KayaPreviewStateMode.empty
                    ? KayaButtonVariant.primary
                    : KayaButtonVariant.outline,
                onPressed: () => setState(() {
                  _previewMode = KayaPreviewStateMode.empty;
                }),
              ),
              KayaButton(
                label: 'Preview Error',
                variant: _previewMode == KayaPreviewStateMode.error
                    ? KayaButtonVariant.primary
                    : KayaButtonVariant.outline,
                onPressed: () => setState(() {
                  _previewMode = KayaPreviewStateMode.error;
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildStatePreviewCard(textTheme),
        ],
      ),
    );
  }

  Widget _buildStatePreviewCard(TextTheme textTheme) {
    switch (_previewMode) {
      case KayaPreviewStateMode.ready:
        return KayaCard(
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.verified_outlined,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Ready State Active', style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'All design tokens, typography scales, and responsive breakpoints are active.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case KayaPreviewStateMode.loading:
        return const KayaCard(
          child: KayaLoadingState(
            title: 'Synchronizing records...',
            subtitle: 'Verifying session and retrieving workspace data.',
          ),
        );
      case KayaPreviewStateMode.empty:
        return KayaEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Sample Empty State',
          description:
              'Empty results are clearly distinguished from network errors.',
          actionLabel: 'Return to Ready',
          onAction: () => setState(() {
            _previewMode = KayaPreviewStateMode.ready;
          }),
        );
      case KayaPreviewStateMode.error:
        return KayaErrorState(
          title: 'Unable to Reach Server',
          message: 'Failed queries are never treated as empty data. Retry when your connection is restored.',
          onRetry: () => setState(() {
            _previewMode = KayaPreviewStateMode.ready;
          }),
        );
    }
  }
}
