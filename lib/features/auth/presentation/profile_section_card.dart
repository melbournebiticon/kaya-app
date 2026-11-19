import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/validation/auth_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:kaya/features/auth/application/auth_controller.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:kaya/features/auth/domain/user_profile.dart';
import 'package:material_ui/material_ui.dart';

/// Displays the authenticated user's profile, inline profile/currency editor,
/// and confirmed Sign Out action.
class ProfileSectionCard extends StatefulWidget {
  const ProfileSectionCard({super.key, required this.controller});

  final AuthController controller;

  @override
  State<ProfileSectionCard> createState() => _ProfileSectionCardState();
}

class _ProfileSectionCardState extends State<ProfileSectionCard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  SupportedCurrency _draftCurrency = SupportedCurrency.php;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final UserProfile? profile = widget.controller.profile;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _draftCurrency = profile?.preferredCurrency ?? SupportedCurrency.php;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEditing(UserProfile profile) {
    widget.controller.clearMessages();
    setState(() {
      _nameController.text = profile.displayName;
      _draftCurrency = profile.preferredCurrency;
      _isEditing = true;
    });
  }

  bool _hasUnsavedChanges(UserProfile profile) {
    return _nameController.text.trim() != profile.displayName ||
        _draftCurrency != profile.preferredCurrency;
  }

  Future<void> _handleCancelEditing(UserProfile profile) async {
    if (_hasUnsavedChanges(profile)) {
      final bool discard = await KayaConfirmDialog.show(
        context,
        title: 'Discard Unsaved Changes?',
        message: 'You have unsaved changes to your profile or currency preference. Discard them?',
        confirmLabel: 'Discard Changes',
      );
      if (!discard || !mounted) {
        return;
      }
    }
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _handleSaveProfile() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final bool succeeded = await widget.controller.updateProfile(
      displayName: _nameController.text,
      preferredCurrency: _draftCurrency,
    );

    if (succeeded && mounted) {
      setState(() {
        _isEditing = false;
      });
    }
  }

  Future<void> _handleConfirmedLogout() async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Sign Out of KAYA?',
      message: 'Signing out will clear your active session and private workspace cache on this device.',
      confirmLabel: 'Sign Out',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await widget.controller.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final UserProfile? profile = widget.controller.profile;
        final TextTheme textTheme = Theme.of(context).textTheme;

        if (profile == null) {
          return const KayaCard(
            child: Text('No authenticated profile loaded.'),
          );
        }

        final bool isSubmitting = widget.controller.isSubmitting;
        final String? errorMessage = widget.controller.lastError?.message;
        final String? noticeMessage = widget.controller.lastNoticeMessage;

        return KayaCard(
          highlighted: true,
          padding: AppSpacing.cardPaddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                          border: Border.all(color: AppColors.borderHighlight),
                        ),
                        child: Text(
                          profile.initials,
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              profile.displayName,
                              style: textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(profile.email, style: textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                  KayaStatusBadge(
                    label:
                        'Currency: ${profile.preferredCurrency.code} (${profile.preferredCurrency.symbol})',
                    type: KayaStatusType.info,
                    customIcon: Icons.payments_outlined,
                  ),
                ],
              ),
              if (errorMessage != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    errorMessage,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              if (noticeMessage != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    noticeMessage,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              if (_isEditing)
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Edit Profile & Currency Preference',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        key: const ValueKey<String>(
                          'profile_edit_display_name',
                        ),
                        controller: _nameController,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: AuthValidators.validateDisplayName,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<SupportedCurrency>(
                        key: const ValueKey<String>('profile_edit_currency'),
                        initialValue: _draftCurrency,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Preferred Currency',
                          prefixIcon: Icon(Icons.currency_exchange_outlined),
                        ),
                        items: SupportedCurrency.values
                            .map(
                              (SupportedCurrency c) =>
                                  DropdownMenuItem<SupportedCurrency>(
                                    value: c,
                                    child: Text(
                                      c.displayLabel,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                            )
                            .toList(),
                        onChanged: isSubmitting
                            ? null
                            : (SupportedCurrency? next) {
                                if (next != null) {
                                  setState(() {
                                    _draftCurrency = next;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          KayaButton(
                            key: const ValueKey<String>('profile_save_button'),
                            label: 'Save Profile',
                            icon: Icons.check,
                            isLoading: isSubmitting,
                            onPressed: _handleSaveProfile,
                          ),
                          KayaButton(
                            key: const ValueKey<String>(
                              'profile_cancel_button',
                            ),
                            label: 'Cancel',
                            variant: KayaButtonVariant.outline,
                            onPressed: isSubmitting
                                ? null
                                : () => _handleCancelEditing(profile),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    KayaButton(
                      key: const ValueKey<String>('profile_edit_button'),
                      label: 'Edit Profile & Currency',
                      icon: Icons.edit_outlined,
                      variant: KayaButtonVariant.secondary,
                      onPressed: () => _startEditing(profile),
                    ),
                    KayaButton(
                      key: const ValueKey<String>('profile_logout_button'),
                      label: 'Sign Out',
                      icon: Icons.logout_outlined,
                      variant: KayaButtonVariant.destructive,
                      onPressed: _handleConfirmedLogout,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
