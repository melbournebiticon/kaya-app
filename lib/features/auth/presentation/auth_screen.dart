import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/validation/auth_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_status_badge.dart';
import 'package:kaya/features/auth/application/auth_controller.dart';
import 'package:kaya/features/auth/domain/supported_currency.dart';
import 'package:material_ui/material_ui.dart';

/// Supported authentication screen modes.
enum KayaAuthMode { signIn, register, passwordRecovery }

/// Phase 2 Authentication Screen supporting Login, Registration, and Password Recovery.
class KayaAuthScreen extends StatefulWidget {
  const KayaAuthScreen({
    super.key,
    required this.controller,
    this.initialMode = KayaAuthMode.signIn,
    this.onReplayOnboarding,
  });

  final AuthController controller;
  final KayaAuthMode initialMode;
  final VoidCallback? onReplayOnboarding;

  @override
  State<KayaAuthScreen> createState() => _KayaAuthScreenState();
}

class _KayaAuthScreenState extends State<KayaAuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  late KayaAuthMode _mode;
  SupportedCurrency _selectedCurrency = SupportedCurrency.php;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(KayaAuthMode nextMode) {
    widget.controller.clearMessages();
    _formKey.currentState?.reset();
    setState(() {
      _mode = nextMode;
    });
  }

  Future<void> _submitForm() async {
    widget.controller.clearMessages();
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    switch (_mode) {
      case KayaAuthMode.signIn:
        await widget.controller.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      case KayaAuthMode.register:
        await widget.controller.register(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _displayNameController.text,
          preferredCurrency: _selectedCurrency,
        );
      case KayaAuthMode.passwordRecovery:
        await widget.controller.requestPasswordRecovery(
          email: _emailController.text,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, _) {
        final TextTheme textTheme = Theme.of(context).textTheme;
        final bool isSubmitting = widget.controller.isSubmitting;
        final String? errorMessage = widget.controller.lastError?.message;
        final String? noticeMessage = widget.controller.lastNoticeMessage;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.maxFormWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Flexible(
                            child: KayaStatusBadge(
                              label: 'KAYA • Secure Workspace',
                              type: KayaStatusType.positive,
                              customIcon: Icons.shield_outlined,
                            ),
                          ),
                          if (widget.onReplayOnboarding != null)
                            KayaButton(
                              label: 'Intro',
                              variant: KayaButtonVariant.ghost,
                              onPressed: isSubmitting
                                  ? null
                                  : widget.onReplayOnboarding,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      KayaCard(
                        highlighted: true,
                        padding: AppSpacing.cardPaddingLarge,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                _titleForMode(_mode),
                                style: textTheme.displaySmall,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _subtitleForMode(_mode),
                                style: textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (errorMessage != null) ...<Widget>[
                                _FeedbackBanner(
                                  message: errorMessage,
                                  isError: true,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              if (noticeMessage != null) ...<Widget>[
                                _FeedbackBanner(
                                  message: noticeMessage,
                                  isError: false,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              if (_mode == KayaAuthMode.register) ...<Widget>[
                                TextFormField(
                                  key: const ValueKey<String>(
                                    'auth_display_name_field',
                                  ),
                                  controller: _displayNameController,
                                  enabled: !isSubmitting,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Display Name',
                                    hintText: 'e.g. Alex Rivera',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: AuthValidators.validateDisplayName,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              TextFormField(
                                key: const ValueKey<String>('auth_email_field'),
                                controller: _emailController,
                                enabled: !isSubmitting,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction:
                                    _mode == KayaAuthMode.passwordRecovery
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'you@example.com',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                validator: AuthValidators.validateEmail,
                              ),
                              if (_mode !=
                                  KayaAuthMode.passwordRecovery) ...<Widget>[
                                const SizedBox(height: AppSpacing.md),
                                TextFormField(
                                  key: const ValueKey<String>(
                                    'auth_password_field',
                                  ),
                                  controller: _passwordController,
                                  enabled: !isSubmitting,
                                  obscureText: _obscurePassword,
                                  textInputAction:
                                      _mode == KayaAuthMode.register
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: _mode == KayaAuthMode.register
                                        ? 'At least 8 chars with letter & number'
                                        : 'Enter your password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (String? value) =>
                                      AuthValidators.validatePassword(
                                        value,
                                        isRegistration:
                                            _mode == KayaAuthMode.register,
                                      ),
                                ),
                              ],
                              if (_mode == KayaAuthMode.register) ...<Widget>[
                                const SizedBox(height: AppSpacing.md),
                                TextFormField(
                                  key: const ValueKey<String>(
                                    'auth_confirm_password_field',
                                  ),
                                  controller: _confirmPasswordController,
                                  enabled: !isSubmitting,
                                  obscureText: _obscureConfirmPassword,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    hintText: 'Re-enter your password',
                                    prefixIcon: const Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _obscureConfirmPassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (String? value) =>
                                      AuthValidators.validateConfirmPassword(
                                        value,
                                        _passwordController.text,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                DropdownButtonFormField<SupportedCurrency>(
                                  key: const ValueKey<String>(
                                    'auth_currency_dropdown',
                                  ),
                                  initialValue: _selectedCurrency,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Preferred Currency',
                                    prefixIcon: Icon(
                                      Icons.currency_exchange_outlined,
                                    ),
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
                                              _selectedCurrency = next;
                                            });
                                          }
                                        },
                                ),
                              ],
                              if (_mode == KayaAuthMode.signIn) ...<Widget>[
                                const SizedBox(height: AppSpacing.xs),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: KayaButton(
                                    label: 'Forgot Password?',
                                    variant: KayaButtonVariant.ghost,
                                    onPressed: isSubmitting
                                        ? null
                                        : () => _switchMode(
                                            KayaAuthMode.passwordRecovery,
                                          ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              KayaButton(
                                key: const ValueKey<String>(
                                  'auth_submit_button',
                                ),
                                label: _primaryButtonLabel(_mode),
                                icon: _primaryButtonIcon(_mode),
                                isLoading: isSubmitting,
                                fullWidth: true,
                                onPressed: _submitForm,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const Divider(),
                              const SizedBox(height: AppSpacing.sm),
                              _buildModeSwitcher(isSubmitting),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeSwitcher(bool isSubmitting) {
    switch (_mode) {
      case KayaAuthMode.signIn:
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: <Widget>[
            Text('New to KAYA?', style: Theme.of(context).textTheme.bodyMedium),
            KayaButton(
              key: const ValueKey<String>('switch_to_register_button'),
              label: 'Create Account',
              variant: KayaButtonVariant.outline,
              onPressed: isSubmitting
                  ? null
                  : () => _switchMode(KayaAuthMode.register),
            ),
          ],
        );
      case KayaAuthMode.register:
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: <Widget>[
            Text(
              'Already have an account?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            KayaButton(
              key: const ValueKey<String>('switch_to_sign_in_button'),
              label: 'Sign In',
              variant: KayaButtonVariant.outline,
              onPressed: isSubmitting
                  ? null
                  : () => _switchMode(KayaAuthMode.signIn),
            ),
          ],
        );
      case KayaAuthMode.passwordRecovery:
        return Center(
          child: KayaButton(
            key: const ValueKey<String>('back_to_sign_in_button'),
            label: 'Back to Sign In',
            icon: Icons.arrow_back,
            variant: KayaButtonVariant.outline,
            onPressed: isSubmitting
                ? null
                : () => _switchMode(KayaAuthMode.signIn),
          ),
        );
    }
  }

  String _titleForMode(KayaAuthMode mode) {
    return switch (mode) {
      KayaAuthMode.signIn => 'Welcome Back to KAYA',
      KayaAuthMode.register => 'Create Your KAYA Account',
      KayaAuthMode.passwordRecovery => 'Recover Your Password',
    };
  }

  String _subtitleForMode(KayaAuthMode mode) {
    return switch (mode) {
      KayaAuthMode.signIn => 'Sign in to access your isolated personal priorities, finances, and Life Vault.',
      KayaAuthMode.register => 'Set up your personal operating system with strict Row Level Security isolation.',
      KayaAuthMode.passwordRecovery => 'Enter your registered email address to receive password reset instructions.',
    };
  }

  String _primaryButtonLabel(KayaAuthMode mode) {
    return switch (mode) {
      KayaAuthMode.signIn => 'Sign In',
      KayaAuthMode.register => 'Create Account',
      KayaAuthMode.passwordRecovery => 'Send Recovery Instructions',
    };
  }

  IconData _primaryButtonIcon(KayaAuthMode mode) {
    return switch (mode) {
      KayaAuthMode.signIn => Icons.login_outlined,
      KayaAuthMode.register => Icons.person_add_outlined,
      KayaAuthMode.passwordRecovery => Icons.send_outlined,
    };
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color fg = isError ? AppColors.error : AppColors.success;
    final Color bg = isError
        ? AppColors.errorSurface
        : AppColors.successSurface;
    final IconData icon = isError
        ? Icons.error_outline
        : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
