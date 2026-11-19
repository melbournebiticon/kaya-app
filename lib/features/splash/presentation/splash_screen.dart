import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';

/// Branded splash & initialization experience for KAYA.
class KayaSplashScreen extends StatefulWidget {
  const KayaSplashScreen({
    super.key,
    required this.onCompleted,
    this.autoAdvanceDuration = const Duration(milliseconds: 900),
  });

  final VoidCallback onCompleted;
  final Duration? autoAdvanceDuration;

  @override
  State<KayaSplashScreen> createState() => _KayaSplashScreenState();
}

class _KayaSplashScreenState extends State<KayaSplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final Duration? duration = widget.autoAdvanceDuration;
    if (duration != null) {
      _timer = Timer(duration, () {
        if (mounted) {
          widget.onCompleted();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.explore_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'KAYA',
                  style: textTheme.displayMedium?.copyWith(
                    letterSpacing: 3.0,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'YOUR LIFE, CLEARER.',
                  style: textTheme.labelMedium?.copyWith(
                    letterSpacing: 2.2,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const KayaStatusBadge(
                  label: 'Initializing personal workspace',
                  type: KayaStatusType.info,
                  customIcon: Icons.verified_user_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
