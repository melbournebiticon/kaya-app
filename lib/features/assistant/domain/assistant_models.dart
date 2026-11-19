import 'package:kaya/features/assistant/domain/ai_assistant_models.dart';

/// Language detected from a user's question.
enum AssistantLanguage { english, taglish }

/// Supported deterministic intents in Phase 8 Smart Assistant Foundation.
enum AssistantIntent {
  tasksToday,
  overdueTasks,
  billsDueSoon,
  safeToSpend,
  expiringDocuments,
  routinesStatus,
  focusToday,
  summarizeDay,
  unsupported,
}

/// Output of the deterministic English & Taglish intent parser.
class ParsedAssistantQuery {
  const ParsedAssistantQuery({
    required this.rawQuery,
    required this.normalizedQuery,
    required this.intent,
    required this.language,
  });

  final String rawQuery;
  final String normalizedQuery;
  final AssistantIntent intent;
  final AssistantLanguage language;
}

/// Explicitly separates loaded empty data from loading, failed, and
/// unauthenticated states so retrieval errors are never misreported as empty.
enum DomainDataStatus { ready, loading, failed, unauthenticated }

/// Read state wrapper for a single KAYA domain snapshot.
class DomainReadState<T> {
  const DomainReadState({required this.status, this.data, this.errorMessage});

  const DomainReadState.ready(T this.data)
    : status = DomainDataStatus.ready,
      errorMessage = null;

  const DomainReadState.loading()
    : status = DomainDataStatus.loading,
      data = null,
      errorMessage = null;

  const DomainReadState.failed([this.errorMessage])
    : status = DomainDataStatus.failed,
      data = null;

  const DomainReadState.unauthenticated()
    : status = DomainDataStatus.unauthenticated,
      data = null,
      errorMessage = null;

  final DomainDataStatus status;
  final T? data;
  final String? errorMessage;

  bool get isReady => status == DomainDataStatus.ready;
  bool get isLoading => status == DomainDataStatus.loading;
  bool get isFailed => status == DomainDataStatus.failed;
  bool get isUnauthenticated => status == DomainDataStatus.unauthenticated;
}

/// Priority classification used across domains in focus rankings.
enum AssistantUrgencyLevel { critical, high, medium, low }

/// Domain sources aggregated by [AssistantContextSnapshot].
enum AssistantSourceDomain {
  tasks(label: 'Tasks'),
  bills(label: 'Bills'),
  reminders(label: 'Reminders'),
  money(label: 'Money'),
  documents(label: 'Life Vault Documents'),
  routines(label: 'Daily Routines'),
  system(label: 'System');

  const AssistantSourceDomain({required this.label});

  final String label;
}

/// Ranked cross-domain item returned by urgency prioritization.
class AssistantUrgentItem {
  const AssistantUrgentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.domain,
    required this.urgency,
    required this.urgencyScore,
  });

  final String id;
  final String title;
  final String subtitle;
  final AssistantSourceDomain domain;
  final AssistantUrgencyLevel urgency;
  final int urgencyScore;
}

/// Visual tone for surfaced daily insights.
enum AssistantInsightTone { critical, warning, positive, info }

/// Grounded daily insight computed directly from verified KAYA records.
class AssistantDailyInsight {
  const AssistantDailyInsight({
    required this.id,
    required this.title,
    required this.detail,
    required this.tone,
    required this.domain,
    required this.followUpPrompt,
  });

  final String id;
  final String title;
  final String detail;
  final AssistantInsightTone tone;
  final AssistantSourceDomain domain;
  final String followUpPrompt;
}

/// Sender role within the in-memory Assistant conversation.
enum AssistantMessageRole { user, assistant }

/// Reply status distinguishing real answers from empty data, retrieval failures,
/// and safe unsupported responses.
enum AssistantReplyStatus { answered, emptyData, retrievalError, unsupported }

/// Single message in KAYA Smart Assistant's in-memory conversation thread.
///
/// Privacy rule (Section 7): redacts prompt/response content in [toString].
class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.role,
    required this.text,
    this.details = const <String>[],
    this.intent,
    this.status = AssistantReplyStatus.answered,
    this.source = AssistantReplySource.deterministic,
    this.failedDomains = const <AssistantSourceDomain>[],
    this.taskSuggestions = const <AiTaskSuggestion>[],
    this.fallbackNotice,
    required this.timestamp,
  });

  final String id;
  final AssistantMessageRole role;
  final String text;
  final List<String> details;
  final AssistantIntent? intent;
  final AssistantReplyStatus status;
  final AssistantReplySource source;
  final List<AssistantSourceDomain> failedDomains;
  final List<AiTaskSuggestion> taskSuggestions;
  final String? fallbackNotice;
  final DateTime timestamp;

  AssistantMessage copyWith({
    AssistantReplySource? source,
    List<AiTaskSuggestion>? taskSuggestions,
    String? fallbackNotice,
  }) {
    return AssistantMessage(
      id: id,
      role: role,
      text: text,
      details: details,
      intent: intent,
      status: status,
      source: source ?? this.source,
      failedDomains: failedDomains,
      taskSuggestions: taskSuggestions ?? this.taskSuggestions,
      fallbackNotice: fallbackNotice ?? this.fallbackNotice,
      timestamp: timestamp,
    );
  }

  @override
  String toString() =>
      'AssistantMessage(id: $id, role: ${role.name}, status: ${status.name}, source: ${source.name}, intent: ${intent?.name}, text: [REDACTED])';
}
