import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/core/validation/assistant_validators.dart';
import 'package:kaya/features/assistant/application/assistant_context_builder.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_gateway.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_models.dart';
import 'package:kaya/features/assistant/domain/ai_context_minimizer.dart';
import 'package:kaya/features/assistant/domain/ai_response_validator.dart';
import 'package:kaya/features/assistant/domain/assistant_context_snapshot.dart';
import 'package:kaya/features/assistant/domain/assistant_intent_parser.dart';
import 'package:kaya/features/assistant/domain/assistant_models.dart';
import 'package:kaya/features/assistant/domain/assistant_response_engine.dart';
import 'package:kaya/features/assistant/domain/assistant_urgency_ranker.dart';
import 'package:kaya/features/tasks/application/task_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Application state controller for Phase 8 (Deterministic Smart Assistant)
/// and Phase 9 (Optional AI Integration with privacy consent, usage/cost
/// controls, response validation, confirmed task proposals, and fallback).
class AssistantController extends ChangeNotifier {
  AssistantController({
    required this.contextBuilder,
    this.aiGateway,
    DateTime Function()? clock,
    String? initialUserId,
    int dailyAiLimit = 25,
    List<Listenable> sourceListenables = const <Listenable>[],
  }) : _clock = clock ?? DateTime.now,
       _dailyAiLimit = dailyAiLimit < 1 ? 1 : dailyAiLimit,
       _activeUserId = (initialUserId?.trim().isEmpty ?? true)
           ? null
           : initialUserId!.trim() {
    _usageQuota = AiUsageQuota(
      usageDate: KayaDateOnly.fromDateTime(_clock()),
      dailyLimit: _dailyAiLimit,
    );
    if (sourceListenables.isNotEmpty) {
      _mergedSourceListenable = Listenable.merge(sourceListenables);
      _mergedSourceListenable!.addListener(_handleSourcesChanged);
    }
  }

  static const List<String> defaultSuggestedQuestions = <String>[
    'What are my tasks today?',
    'Ano tasks ko ngayon?',
    'May overdue tasks ba ako?',
    'What bills are due soon?',
    'Magkano safe to spend ko?',
    'Are my documents expiring?',
    'What should I focus on today?',
    'Summarize my day.',
  ];

  final AssistantContextBuilder contextBuilder;
  final AiAssistantGateway? aiGateway;
  final DateTime Function() _clock;
  final int _dailyAiLimit;

  Listenable? _mergedSourceListenable;
  String? _activeUserId;
  int _userEpoch = 0;
  int _messageSeq = 0;
  bool _isRefreshing = false;
  bool _isThinkingAi = false;

  AiConsentSettings _aiConsent = const AiConsentSettings();
  late AiUsageQuota _usageQuota;

  final List<AssistantMessage> _messages = <AssistantMessage>[];

  String? get activeUserId => _activeUserId;
  bool get isRefreshing => _isRefreshing;
  bool get isThinkingAi => _isThinkingAi;
  bool get hasConversation => _messages.isNotEmpty;
  bool get isAiAvailable => aiGateway != null;
  AiConsentSettings get aiConsent => _aiConsent;

  AiUsageQuota get usageQuota {
    final KayaDateOnly today = KayaDateOnly.fromDateTime(_clock());
    if (_usageQuota.usageDate != today) {
      _usageQuota = AiUsageQuota(usageDate: today, dailyLimit: _dailyAiLimit);
    }
    return _usageQuota;
  }

  List<AssistantMessage> get messages =>
      List<AssistantMessage>.unmodifiable(_messages);

  AssistantContextSnapshot get currentSnapshot =>
      contextBuilder.build(activeUserId: _activeUserId);

  List<AssistantDailyInsight> get dailyInsights =>
      AssistantUrgencyRanker.buildDailyInsights(currentSnapshot);

  List<String> get suggestedQuestions {
    final List<String> prompts = List<String>.from(defaultSuggestedQuestions);
    if (_aiConsent.aiEnabled) {
      prompts.add('Help me plan my tasks today.');
    }
    if (currentSnapshot.todayScheduledRoutines.isNotEmpty) {
      prompts.add('Am I keeping up with my routines?');
    }
    return List<String>.unmodifiable(prompts);
  }

  void _handleSourcesChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _mergedSourceListenable?.removeListener(_handleSourcesChanged);
    _mergedSourceListenable = null;
    super.dispose();
  }

  /// Binds Assistant to [userId], clearing the in-memory conversation,
  /// AI consent flags, and usage counters on logout or account switch.
  void bindAuthenticatedUser(String? userId) {
    final String? normalized = (userId?.trim().isEmpty ?? true)
        ? null
        : userId!.trim();
    if (_activeUserId == normalized) {
      return;
    }

    _userEpoch++;
    _activeUserId = normalized;
    _isRefreshing = false;
    _isThinkingAi = false;
    _aiConsent = const AiConsentSettings();
    _usageQuota = AiUsageQuota(
      usageDate: KayaDateOnly.fromDateTime(_clock()),
      dailyLimit: _dailyAiLimit,
    );
    _messages.clear();
    notifyListeners();
  }

  /// Updates explicit per-user AI and sensitive-data sharing consent.
  void updateAiConsent(AiConsentSettings next) {
    if (_aiConsent == next) {
      return;
    }
    _aiConsent = next;
    notifyListeners();
  }

  /// Submits a synchronous deterministic Phase 8 query grounded in real KAYA
  /// records (never sends data to external AI).
  AssistantMessage? ask(String rawPrompt) {
    final String? validationError = AssistantValidators.validatePrompt(
      rawPrompt,
    );
    if (validationError != null) {
      return null;
    }

    final String cleanPrompt = rawPrompt.trim();
    final DateTime now = _clock();
    final String userMsgId = 'msg_${++_messageSeq}';
    final String replyMsgId = 'msg_${++_messageSeq}';

    final ParsedAssistantQuery parsed = AssistantIntentParser.parse(
      cleanPrompt,
    );
    final AssistantContextSnapshot snapshot = currentSnapshot;
    final AssistantMessage reply = AssistantResponseEngine.generateReply(
      parsed: parsed,
      snapshot: snapshot,
      messageId: replyMsgId,
      timestamp: now,
    );

    _messages.add(
      AssistantMessage(
        id: userMsgId,
        role: AssistantMessageRole.user,
        text: cleanPrompt,
        intent: parsed.intent,
        timestamp: now,
      ),
    );
    _messages.add(reply);
    notifyListeners();
    return reply;
  }

  /// Submits a prompt using optional server-side AI when enabled, with strict
  /// data minimization, response validation, daily quota enforcement, and
  /// automatic deterministic fallback.
  Future<AssistantMessage?> askSmart(String rawPrompt) async {
    final String? validationError = AssistantValidators.validatePrompt(
      rawPrompt,
    );
    if (validationError != null || _isThinkingAi) {
      return null;
    }

    if (!_aiConsent.aiEnabled || aiGateway == null) {
      return ask(rawPrompt);
    }

    final String cleanPrompt = rawPrompt.trim();
    final DateTime now = _clock();
    final String userMsgId = 'msg_${++_messageSeq}';
    final String replyMsgId = 'msg_${++_messageSeq}';
    final ParsedAssistantQuery parsed = AssistantIntentParser.parse(
      cleanPrompt,
    );
    final AssistantContextSnapshot snapshot = currentSnapshot;

    // Fail closed if unauthenticated without calling external AI.
    if (!snapshot.isAuthenticated || _activeUserId == null) {
      return ask(rawPrompt);
    }

    final AiUsageQuota quota = usageQuota;
    if (quota.isExceeded) {
      return _appendDeterministicFallback(
        userMsgId: userMsgId,
        replyMsgId: replyMsgId,
        cleanPrompt: cleanPrompt,
        parsed: parsed,
        snapshot: snapshot,
        now: now,
        fallbackNotice:
            'Daily AI limit reached (${quota.usedToday}/${quota.dailyLimit}). Answered with deterministic KAYA data.',
      );
    }

    final int requestEpoch = _userEpoch;
    _messages.add(
      AssistantMessage(
        id: userMsgId,
        role: AssistantMessageRole.user,
        text: cleanPrompt,
        intent: parsed.intent,
        timestamp: now,
      ),
    );
    _isThinkingAi = true;
    notifyListeners();

    try {
      final AiMinimizedContextPayload minimized =
          AiContextMinimizer.buildMinimizedPayload(
            snapshot: snapshot,
            consent: _aiConsent,
          );
      final List<Map<String, String>> recentHistory = _messages
          .take(_messages.length - 1)
          .toList()
          .reversed
          .take(4)
          .toList()
          .reversed
          .map(
            (AssistantMessage m) => <String, String>{
              'role': m.role.name,
              'text': m.text,
            },
          )
          .toList(growable: false);

      final AiGatewayResponse rawResponse = await aiGateway!.generateAssistance(
        authenticatedUserId: _activeUserId!,
        request: AiGatewayRequest(
          prompt: cleanPrompt,
          language: parsed.language,
          minimizedContext: minimized,
          recentHistory: recentHistory,
          maxOutputTokens: quota.maxOutputTokens,
        ),
      );

      if (requestEpoch != _userEpoch) {
        return null;
      }

      final AiGatewayResponse? validated = AiResponseValidator.validate(
        rawResponse,
      );
      if (validated == null) {
        _isThinkingAi = false;
        return _appendFallbackReplyOnly(
          replyMsgId: replyMsgId,
          parsed: parsed,
          snapshot: snapshot,
          now: _clock(),
          fallbackNotice: 'AI response did not pass safety validation. Showing deterministic KAYA answer instead.',
        );
      }

      _usageQuota = usageQuota.increment(
        estimatedTokens: validated.estimatedTokens,
      );
      final AssistantMessage aiReply = AssistantMessage(
        id: replyMsgId,
        role: AssistantMessageRole.assistant,
        text: validated.replyText,
        details: validated.details,
        intent: parsed.intent,
        status: AssistantReplyStatus.answered,
        source: AssistantReplySource.ai,
        taskSuggestions: validated.suggestedTasks,
        timestamp: _clock(),
      );
      _messages.add(aiReply);
      _isThinkingAi = false;
      notifyListeners();
      return aiReply;
    } catch (_) {
      if (requestEpoch != _userEpoch) {
        return null;
      }
      _isThinkingAi = false;
      return _appendFallbackReplyOnly(
        replyMsgId: replyMsgId,
        parsed: parsed,
        snapshot: snapshot,
        now: _clock(),
        fallbackNotice: 'AI service unavailable right now. Showing deterministic KAYA answer instead.',
      );
    }
  }

  AssistantMessage _appendDeterministicFallback({
    required String userMsgId,
    required String replyMsgId,
    required String cleanPrompt,
    required ParsedAssistantQuery parsed,
    required AssistantContextSnapshot snapshot,
    required DateTime now,
    required String fallbackNotice,
  }) {
    _messages.add(
      AssistantMessage(
        id: userMsgId,
        role: AssistantMessageRole.user,
        text: cleanPrompt,
        intent: parsed.intent,
        timestamp: now,
      ),
    );
    return _appendFallbackReplyOnly(
      replyMsgId: replyMsgId,
      parsed: parsed,
      snapshot: snapshot,
      now: now,
      fallbackNotice: fallbackNotice,
    );
  }

  AssistantMessage _appendFallbackReplyOnly({
    required String replyMsgId,
    required ParsedAssistantQuery parsed,
    required AssistantContextSnapshot snapshot,
    required DateTime now,
    required String fallbackNotice,
  }) {
    final AssistantMessage base = AssistantResponseEngine.generateReply(
      parsed: parsed,
      snapshot: snapshot,
      messageId: replyMsgId,
      timestamp: now,
    );
    final AssistantMessage fallback = base.copyWith(
      source: AssistantReplySource.deterministicFallback,
      fallbackNotice: fallbackNotice,
    );
    _messages.add(fallback);
    notifyListeners();
    return fallback;
  }

  /// Creates a real task in [TaskController] ONLY after explicit user
  /// confirmation of an [AiTaskSuggestion].
  Future<bool> confirmTaskSuggestion({
    required String messageId,
    required String suggestionId,
  }) async {
    final TaskController? taskCtrl = contextBuilder.taskController;
    if (taskCtrl == null || _activeUserId == null) {
      return false;
    }
    final int msgIdx = _messages.indexWhere(
      (AssistantMessage m) => m.id == messageId,
    );
    if (msgIdx == -1) {
      return false;
    }
    final AssistantMessage msg = _messages[msgIdx];
    final int sIdx = msg.taskSuggestions.indexWhere(
      (AiTaskSuggestion s) => s.id == suggestionId,
    );
    if (sIdx == -1 || !msg.taskSuggestions[sIdx].isPending) {
      return false;
    }

    final AiTaskSuggestion suggestion = msg.taskSuggestions[sIdx];
    final bool created = await taskCtrl.createTask(
      title: suggestion.title,
      priority: suggestion.priority,
      category: suggestion.category,
      dueDate: suggestion.dueDate,
    );
    if (!created) {
      return false;
    }

    final List<AiTaskSuggestion> updated = List<AiTaskSuggestion>.from(
      msg.taskSuggestions,
    );
    updated[sIdx] = suggestion.copyWith(isConfirmed: true);
    _messages[msgIdx] = msg.copyWith(
      taskSuggestions: List<AiTaskSuggestion>.unmodifiable(updated),
    );
    notifyListeners();
    return true;
  }

  void dismissTaskSuggestion({
    required String messageId,
    required String suggestionId,
  }) {
    final int msgIdx = _messages.indexWhere(
      (AssistantMessage m) => m.id == messageId,
    );
    if (msgIdx == -1) {
      return;
    }
    final AssistantMessage msg = _messages[msgIdx];
    final int sIdx = msg.taskSuggestions.indexWhere(
      (AiTaskSuggestion s) => s.id == suggestionId,
    );
    if (sIdx == -1 || !msg.taskSuggestions[sIdx].isPending) {
      return;
    }
    final List<AiTaskSuggestion> updated = List<AiTaskSuggestion>.from(
      msg.taskSuggestions,
    );
    updated[sIdx] = updated[sIdx].copyWith(isDismissed: true);
    _messages[msgIdx] = msg.copyWith(
      taskSuggestions: List<AiTaskSuggestion>.unmodifiable(updated),
    );
    notifyListeners();
  }

  void clearConversation() {
    if (_messages.isEmpty) {
      return;
    }
    _messages.clear();
    notifyListeners();
  }

  Future<void> retryFailedData({
    List<AssistantSourceDomain> domains = const <AssistantSourceDomain>[],
  }) async {
    if (_isRefreshing || _activeUserId == null) {
      return;
    }
    final int requestEpoch = _userEpoch;
    _isRefreshing = true;
    notifyListeners();

    try {
      await contextBuilder.retryFailedDomains(domains);
    } finally {
      if (requestEpoch == _userEpoch) {
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }
}
