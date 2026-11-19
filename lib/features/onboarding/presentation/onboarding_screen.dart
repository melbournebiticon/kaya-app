import 'package:material_ui/material_ui.dart';
import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';

/// Data model for a single onboarding step.
class KayaOnboardingSlide {
  const KayaOnboardingSlide({
    required this.badgeLabel,
    required this.title,
    required this.description,
    required this.highlights,
    required this.icon,
  });

  final String badgeLabel;
  final String title;
  final String description;
  final List<String> highlights;
  final IconData icon;
}

/// Interactive multi-step onboarding experience for KAYA.
class KayaOnboardingScreen extends StatefulWidget {
  const KayaOnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  static const List<KayaOnboardingSlide> slides = <KayaOnboardingSlide>[
    KayaOnboardingSlide(
      badgeLabel: 'Personal Operating System',
      title: 'Your Life, Clearer.',
      description: 'KAYA brings your daily priorities, finances, bills, documents, and routines into one calm, connected workspace.',
      highlights: <String>[
        'Reduce mental clutter with a unified daily view',
        'Know what requires your attention right now',
        'Designed for clarity, privacy, and reliability',
      ],
      icon: Icons.explore_outlined,
    ),
    KayaOnboardingSlide(
      badgeLabel: 'Today & Life Organization',
      title: 'Stay Ahead of Tasks, Bills & Documents',
      description: 'Never lose track of due dates, expiring IDs, recurring routines, or borrowed belongings.',
      highlights: <String>[
        'Prioritized Today view for tasks and reminders',
        'Life Vault for important documents and expiration alerts',
        'Daily routines, smart checklists, and shopping lists',
      ],
      icon: Icons.folder_special_outlined,
    ),
    KayaOnboardingSlide(
      badgeLabel: 'Money & Safe to Spend',
      title: 'Honest Financial Clarity',
      description: 'Track income, expenses, budgets, and unpaid bills with one centralized Safe to Spend calculation.',
      highlights: <String>[
        'Centralized decimal-safe financial calculations',
        'Separate actual transactions from shopping estimates',
        'Answer "Can I buy this?" with confidence',
      ],
      icon: Icons.account_balance_wallet_outlined,
    ),
    KayaOnboardingSlide(
      badgeLabel: 'Grounded Assistant',
      title: 'Ask KAYA in English or Taglish',
      description: 'Get direct, trustworthy answers grounded strictly in your own KAYA data—with zero fabricated numbers.',
      highlights: <String>[
        '"What should I focus on today?"',
        '"Magkano ang Safe to Spend ko?"',
        '"May overdue tasks o bills ba ako?"',
      ],
      icon: Icons.auto_awesome_outlined,
    ),
  ];

  @override
  State<KayaOnboardingScreen> createState() => _KayaOnboardingScreenState();
}

class _KayaOnboardingScreenState extends State<KayaOnboardingScreen> {
  int _currentIndex = 0;

  bool get _isLastSlide =>
      _currentIndex == KayaOnboardingScreen.slides.length - 1;

  void _handleNext() {
    if (_isLastSlide) {
      widget.onFinished();
      return;
    }
    setState(() {
      _currentIndex++;
    });
  }

  void _handleBack() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final KayaOnboardingSlide slide =
        KayaOnboardingScreen.slides[_currentIndex];
    final int totalSlides = KayaOnboardingScreen.slides.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxFormWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: KayaStatusBadge(
                          label: 'Step ${_currentIndex + 1} of $totalSlides',
                          type: KayaStatusType.info,
                          customIcon: Icons.flag_outlined,
                        ),
                      ),
                      if (!_isLastSlide)
                        KayaButton(
                          label: 'Skip',
                          variant: KayaButtonVariant.ghost,
                          onPressed: widget.onFinished,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: SingleChildScrollView(
                      child: KayaCard(
                        padding: AppSpacing.cardPaddingLarge,
                        highlighted: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusLg,
                                ),
                                border: Border.all(
                                  color: AppColors.borderHighlight,
                                ),
                              ),
                              child: Icon(
                                slide.icon,
                                size: 30,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            KayaStatusBadge(
                              label: slide.badgeLabel,
                              type: KayaStatusType.positive,
                              customIcon: Icons.verified_outlined,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(slide.title, style: textTheme.displaySmall),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              slide.description,
                              style: textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const Divider(),
                            const SizedBox(height: AppSpacing.md),
                            for (final String point
                                in slide.highlights) ...<Widget>[
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.check_circle_outline,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        point,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(totalSlides, (int index) {
                      final bool selected = index == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: selected ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusPill,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      if (_currentIndex > 0) ...<Widget>[
                        Expanded(
                          child: KayaButton(
                            label: 'Back',
                            variant: KayaButtonVariant.outline,
                            onPressed: _handleBack,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        flex: 2,
                        child: KayaButton(
                          label: _isLastSlide ? 'Enter KAYA' : 'Next',
                          icon: _isLastSlide
                              ? Icons.arrow_forward
                              : Icons.navigate_next,
                          onPressed: _handleNext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
