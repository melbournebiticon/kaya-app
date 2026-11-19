import 'package:kaya/app/theme/app_colors.dart';
import 'package:kaya/app/theme/app_spacing.dart';
import 'package:kaya/core/utils/responsive_layout.dart';
import 'package:kaya/core/validation/assistant_validators.dart';
import 'package:kaya/core/widgets/kaya_button.dart';
import 'package:kaya/core/widgets/kaya_card.dart';
import 'package:kaya/core/widgets/kaya_section_header.dart';
import 'package:kaya/core/widgets/kaya_state_views.dart';
import 'package:kaya/features/assistant/application/assistant_context_builder.dart';
import 'package:kaya/features/assistant/application/assistant_controller.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_models.dart';
import 'package:kaya/features/assistant/domain/assistant_context_snapshot.dart';
import 'package:kaya/features/assistant/domain/assistant_models.dart';
import 'package:material_ui/material_ui.dart';

/// Assistant module screen (Phase 8 Deterministic Foundation + Phase 9
/// Optional AI Integration with privacy consent, usage quota, confirmed task
/// proposals, and deterministic fallback).
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.assistantController});

  final AssistantController? assistantController;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AssistantController? _fallbackController;
  String? _inputError;

  AssistantController get _effectiveController =>
      widget.assistantController ??
      (_fallbackController ??= AssistantController(
        contextBuilder: AssistantContextBuilder(),
      ));

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _fallbackController?.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmit(AssistantController ctrl) async {
    final String? validationError = AssistantValidators.validatePrompt(
      _promptController.text,
    );
    if (validationError != null) {
      setState(() {
        _inputError = validationError;
      });
      return;
    }

    final String prompt = _promptController.text.trim();
    _promptController.clear();
    if (_inputError != null) {
      setState(() {
        _inputError = null;
      });
    }
    await _askPrompt(ctrl, prompt);
  }

  Future<void> _askPrompt(AssistantController ctrl, String prompt) async {
    final AssistantMessage? reply = await ctrl.askSmart(prompt);
    if (reply != null) {
      _scrollToBottom();
    }
  }

  Future<void> _openPrivacyDialog(AssistantController ctrl) async {
    final AiConsentSettings? updated = await showDialog<AiConsentSettings>(
      context: context,
      builder: (BuildContext dialogContext) => _AiPrivacyConsentDialog(
        initialConsent: ctrl.aiConsent,
        quota: ctrl.usageQuota,
      ),
    );
    if (updated != null) {
      ctrl.updateAiConsent(updated);
    }
  }

  Future<void> _handleConfirmTaskSuggestion(
    AssistantController ctrl,
    AssistantMessage message,
    AiTaskSuggestion suggestion,
  ) async {
    final bool confirmed = await KayaConfirmDialog.show(
      context,
      title: 'Add Suggested Task?',
      message:
          'Add "${suggestion.title}" (${suggestion.priority.label} priority) to your Tasks?',
      confirmLabel: 'Add Task',
    );
    if (confirmed) {
      await ctrl.confirmTaskSuggestion(
        messageId: message.id,
        suggestionId: suggestion.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AssistantController ctrl = _effectiveController;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (BuildContext context, _) => _buildContent(context, ctrl),
    );
  }

  Widget _buildContent(BuildContext context, AssistantController ctrl) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AssistantContextSnapshot snapshot = ctrl.currentSnapshot;
    final List<AssistantDailyInsight> insights = ctrl.dailyInsights;
    final List<String> suggestions = ctrl.suggestedQuestions;
    final List<AssistantMessage> messages = ctrl.messages;

    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final EdgeInsets padding = KayaResponsive.pagePaddingForWidth(
                constraints.maxWidth,
              );
              return SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.maxContentWidth,
                    ),
                    child: Padding(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildHeaderCard(context, textTheme, ctrl, snapshot),
                          const SizedBox(height: AppSpacing.lg),
                          _buildInsightsSection(
                            context,
                            textTheme,
                            ctrl,
                            snapshot,
                            insights,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildSuggestedQuestions(ctrl, suggestions),
                          const SizedBox(height: AppSpacing.lg),
                          _buildConversationSection(
                            context,
                            textTheme,
                            ctrl,
                            messages,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildComposerBar(context, textTheme, ctrl),
      ],
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    TextTheme textTheme,
    AssistantController ctrl,
    AssistantContextSnapshot snapshot,
  ) {
    final AiConsentSettings consent = ctrl.aiConsent;
    final AiUsageQuota quota = ctrl.usageQuota;

    return KayaCard(
      padding: AppSpacing.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'English & Taglish',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              if (ctrl.hasConversation)
                TextButton.icon(
                  key: const ValueKey<String>('assistant_clear_button'),
                  onPressed: ctrl.clearConversation,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('KAYA Smart Assistant', style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ask about your tasks, bills, documents, routines, or Safe to Spend balance using only your real KAYA records.',
            style: textTheme.bodyMedium,
          ),
          if (snapshot.userDisplayName != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Account: ${snapshot.userDisplayName} • ${consent.aiEnabled ? 'Optional AI enabled' : 'Deterministic local mode'}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (ctrl.isAiAvailable) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Switch(
                      key: const ValueKey<String>('assistant_ai_mode_switch'),
                      value: consent.aiEnabled,
                      onChanged: (bool enabled) {
                        ctrl.updateAiConsent(
                          consent.copyWith(aiEnabled: enabled),
                        );
                      },
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        consent.aiEnabled
                            ? 'AI Assist ON (${quota.usedToday}/${quota.dailyLimit} today)'
                            : 'Optional AI Assist (OFF)',
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: consent.aiEnabled
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  key: const ValueKey<String>('assistant_privacy_button'),
                  onPressed: () => _openPrivacyDialog(ctrl),
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('Privacy & Limits'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsSection(
    BuildContext context,
    TextTheme textTheme,
    AssistantController ctrl,
    AssistantContextSnapshot snapshot,
    List<AssistantDailyInsight> insights,
  ) {
    return Column(
      key: const ValueKey<String>('assistant_daily_insights_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KayaSectionHeader(
          title: 'Daily Insights',
          subtitle: 'Live highlights from your loaded KAYA records',
          trailing: snapshot.hasAnyFailure
              ? KayaButton(
                  key: const ValueKey<String>('assistant_retry_data_button'),
                  label: 'Retry',
                  icon: Icons.refresh_outlined,
                  variant: KayaButtonVariant.secondary,
                  isLoading: ctrl.isRefreshing,
                  onPressed: () => ctrl.retryFailedData(),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (int i = 0; i < insights.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _InsightRowCard(
            insight: insights[i],
            onTap: () => _askPrompt(ctrl, insights[i].followUpPrompt),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestedQuestions(
    AssistantController ctrl,
    List<String> suggestions,
  ) {
    return Column(
      key: const ValueKey<String>('assistant_suggested_questions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const KayaSectionHeader(
          title: 'Suggested Questions',
          subtitle: 'Tap any English or Taglish prompt to check your records',
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (int i = 0; i < suggestions.length; i++)
              ActionChip(
                key: ValueKey<String>('assistant_prompt_chip_$i'),
                avatar: const Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(suggestions[i]),
                onPressed: ctrl.isThinkingAi
                    ? null
                    : () => _askPrompt(ctrl, suggestions[i]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildConversationSection(
    BuildContext context,
    TextTheme textTheme,
    AssistantController ctrl,
    List<AssistantMessage> messages,
  ) {
    return Column(
      key: const ValueKey<String>('assistant_conversation_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const KayaSectionHeader(
          title: 'Conversation',
          subtitle: 'In-memory session cleared when you sign out',
        ),
        const SizedBox(height: AppSpacing.sm),
        if (messages.isEmpty)
          const KayaEmptyState(
            icon: Icons.smart_toy_outlined,
            title: 'No Conversation Active',
            description: 'Tap a suggested prompt above or ask a question below to see your tasks, bills, expiring documents, or Safe to Spend.',
          )
        else
          for (int i = 0; i < messages.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _ConversationBubble(
              message: messages[i],
              isRetrying: ctrl.isRefreshing,
              onRetry:
                  messages[i].status == AssistantReplyStatus.retrievalError &&
                      messages[i].failedDomains.isNotEmpty
                  ? () =>
                        ctrl.retryFailedData(domains: messages[i].failedDomains)
                  : null,
              onConfirmTaskSuggestion: (AiTaskSuggestion suggestion) =>
                  _handleConfirmTaskSuggestion(ctrl, messages[i], suggestion),
              onDismissTaskSuggestion: (AiTaskSuggestion suggestion) =>
                  ctrl.dismissTaskSuggestion(
                    messageId: messages[i].id,
                    suggestionId: suggestion.id,
                  ),
            ),
          ],
      ],
    );
  }

  Widget _buildComposerBar(
    BuildContext context,
    TextTheme textTheme,
    AssistantController ctrl,
  ) {
    final double width = MediaQuery.sizeOf(context).width;
    final EdgeInsets pagePadding = KayaResponsive.pagePaddingForWidth(width);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                pagePadding.left,
                AppSpacing.sm,
                pagePadding.right,
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: const ValueKey<String>('assistant_prompt_input'),
                          controller: _promptController,
                          maxLength: AssistantValidators.maxPromptLength,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSubmit(ctrl),
                          onChanged: (_) {
                            if (_inputError != null) {
                              setState(() {
                                _inputError = null;
                              });
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'Ask in English or Taglish (e.g., Magkano safe to spend ko?)',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      KayaButton(
                        key: const ValueKey<String>('assistant_send_button'),
                        label: 'Ask',
                        icon: Icons.send_outlined,
                        isLoading: ctrl.isThinkingAi,
                        onPressed: () => _handleSubmit(ctrl),
                      ),
                    ],
                  ),
                  if (_inputError != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _inputError!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiPrivacyConsentDialog extends StatefulWidget {
  const _AiPrivacyConsentDialog({
    required this.initialConsent,
    required this.quota,
  });

  final AiConsentSettings initialConsent;
  final AiUsageQuota quota;

  @override
  State<_AiPrivacyConsentDialog> createState() =>
      _AiPrivacyConsentDialogState();
}

class _AiPrivacyConsentDialogState extends State<_AiPrivacyConsentDialog> {
  late bool _aiEnabled;
  late bool _shareFinancial;
  late bool _shareDocuments;

  @override
  void initState() {
    super.initState();
    _aiEnabled = widget.initialConsent.aiEnabled;
    _shareFinancial = widget.initialConsent.shareFinancialSummary;
    _shareDocuments = widget.initialConsent.shareDocumentAlerts;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('AI Privacy & Usage Limits'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'KAYA minimizes personal data before any server-side AI request. Raw notes, IDs, locations, and individual transactions are never sent. AI never modifies records without your confirmation.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Daily quota: ${widget.quota.usedToday}/${widget.quota.dailyLimit} requests used • Max ${widget.quota.maxOutputTokens} output tokens/reply.',
                style: textTheme.labelSmall?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Optional AI Assist'),
                subtitle: const Text(
                  'Falls back automatically to deterministic local data if unavailable.',
                ),
                value: _aiEnabled,
                onChanged: (bool val) => setState(() => _aiEnabled = val),
              ),
              SwitchListTile(
                key: const ValueKey<String>('ai_consent_financial_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Share Financial Summary'),
                subtitle: const Text(
                  'Allows sharing aggregated Safe to Spend status only (never individual transactions).',
                ),
                value: _shareFinancial,
                onChanged: _aiEnabled
                    ? (bool val) => setState(() => _shareFinancial = val)
                    : null,
              ),
              SwitchListTile(
                key: const ValueKey<String>('ai_consent_documents_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Share Document Expiration Alerts'),
                subtitle: const Text(
                  'Allows sharing expiring document titles & status only (never notes or physical locations).',
                ),
                value: _shareDocuments,
                onChanged: _aiEnabled
                    ? (bool val) => setState(() => _shareDocuments = val)
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        KayaButton(
          label: 'Cancel',
          variant: KayaButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        KayaButton(
          key: const ValueKey<String>('ai_consent_save_button'),
          label: 'Save',
          onPressed: () => Navigator.of(context).pop(
            AiConsentSettings(
              aiEnabled: _aiEnabled,
              shareFinancialSummary: _aiEnabled && _shareFinancial,
              shareDocumentAlerts: _aiEnabled && _shareDocuments,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightRowCard extends StatelessWidget {
  const _InsightRowCard({required this.insight, required this.onTap});

  final AssistantDailyInsight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final (Color accent, IconData icon) = switch (insight.tone) {
      AssistantInsightTone.critical => (
        AppColors.error,
        Icons.warning_amber_outlined,
      ),
      AssistantInsightTone.warning => (
        AppColors.warning,
        Icons.schedule_outlined,
      ),
      AssistantInsightTone.positive => (
        AppColors.success,
        Icons.check_circle_outline,
      ),
      AssistantInsightTone.info => (AppColors.info, Icons.lightbulb_outline),
    };

    return KayaCard(
      onTap: onTap,
      highlighted: insight.tone == AssistantInsightTone.critical,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(insight.title, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  insight.detail,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _ConversationBubble extends StatelessWidget {
  const _ConversationBubble({
    required this.message,
    required this.isRetrying,
    this.onRetry,
    this.onConfirmTaskSuggestion,
    this.onDismissTaskSuggestion,
  });

  final AssistantMessage message;
  final bool isRetrying;
  final VoidCallback? onRetry;
  final ValueChanged<AiTaskSuggestion>? onConfirmTaskSuggestion;
  final ValueChanged<AiTaskSuggestion>? onDismissTaskSuggestion;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isUser = message.role == AssistantMessageRole.user;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: KayaCard(
            backgroundColor: AppColors.primaryContainer,
            borderColor: AppColors.borderHighlight,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              message.text,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    final (IconData icon, Color iconColor) = switch (message.status) {
      AssistantReplyStatus.answered => (
        Icons.auto_awesome_outlined,
        AppColors.primary,
      ),
      AssistantReplyStatus.emptyData => (
        Icons.inbox_outlined,
        AppColors.secondary,
      ),
      AssistantReplyStatus.retrievalError => (
        Icons.error_outline,
        AppColors.error,
      ),
      AssistantReplyStatus.unsupported => (
        Icons.info_outline,
        AppColors.warning,
      ),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: KayaCard(
          highlighted: message.status == AssistantReplyStatus.retrievalError,
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (message.source !=
                  AssistantReplySource.deterministic) ...<Widget>[
                Text(
                  message.source.label,
                  style: textTheme.labelSmall?.copyWith(
                    color: message.source == AssistantReplySource.ai
                        ? AppColors.secondary
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      message.text,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (message.fallbackNotice != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: Text(
                    message.fallbackNotice!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
              if (message.details.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                for (final String line in message.details) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.lg,
                      top: 2,
                      bottom: 2,
                    ),
                    child: Text(
                      line,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
              if (message.taskSuggestions.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Suggested Tasks (confirmation required)',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final AiTaskSuggestion s
                    in message.taskSuggestions) ...<Widget>[
                  if (!s.isDismissed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(s.title, style: textTheme.bodySmall),
                                  Text(
                                    '${s.priority.label} • ${s.category.label}${s.dueDate != null ? ' • ${s.dueDate!.formatReadable()}' : ''}',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (s.isConfirmed)
                              Text(
                                'Added',
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else ...<Widget>[
                              TextButton(
                                key: ValueKey<String>(
                                  'ai_dismiss_task_${s.id}',
                                ),
                                onPressed: onDismissTaskSuggestion == null
                                    ? null
                                    : () => onDismissTaskSuggestion!(s),
                                child: const Text('Dismiss'),
                              ),
                              TextButton(
                                key: ValueKey<String>(
                                  'ai_confirm_task_${s.id}',
                                ),
                                onPressed: onConfirmTaskSuggestion == null
                                    ? null
                                    : () => onConfirmTaskSuggestion!(s),
                                child: const Text('Add Task'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ],
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: KayaButton(
                    label: 'Retry',
                    icon: Icons.refresh_outlined,
                    variant: KayaButtonVariant.secondary,
                    isLoading: isRetrying,
                    onPressed: onRetry,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
