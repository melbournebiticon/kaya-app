import 'package:kaya/features/assistant/domain/assistant_models.dart';

/// Deterministic, offline English & Taglish intent parser for Phase 8.
///
/// Enforces read-only queries over real user data and safely routes
/// out-of-scope or write/mutation requests to [AssistantIntent.unsupported].
abstract final class AssistantIntentParser {
  static const Set<String> _taglishTokens = <String>{
    'ano',
    'anong',
    'magkano',
    'ko',
    'ba',
    'ako',
    'ngayon',
    'may',
    'meron',
    'wala',
    'araw',
    'unahin',
    'gawin',
    'gagawin',
    'gawain',
    'bayarin',
    'babayaran',
    'bayaran',
    'pera',
    'gastos',
    'badyet',
    'dokumento',
    'kamusta',
    'kumusta',
    'ibuod',
    'buod',
    'bukas',
    'kailangan',
    'dapat',
    'kong',
    'sa',
    'ang',
    'ng',
    'mga',
    'na',
    'pa',
    'po',
    'natitira',
    'lampas',
    'lagpas',
    'nahuli',
    'pokus',
    'burahin',
    'magdagdag',
    'gumawa',
  };

  static const Set<String> _mutationVerbs = <String>{
    'add',
    'create',
    'delete',
    'remove',
    'edit',
    'update',
    'record',
    'log',
    'mark',
    'complete',
    'magdagdag',
    'burahin',
    'gumawa',
    'bayaran',
    'idelete',
  };

  static const Set<String> _billTokens = <String>{
    'bill',
    'bills',
    'bayarin',
    'babayaran',
    'utilities',
    'kuryente',
    'rent',
  };

  static const Set<String> _docTokens = <String>{
    'document',
    'documents',
    'doc',
    'docs',
    'dokumento',
    'vault',
    'passport',
    'license',
  };

  static const Set<String> _overdueTokens = <String>{
    'overdue',
    'late',
    'missed',
    'lampas',
    'lagpas',
    'nahuli',
  };

  /// Parses [rawInput] into a normalized query, detected language, and intent.
  static ParsedAssistantQuery parse(String rawInput) {
    final String cleaned = rawInput
        .trim()
        .toLowerCase()
        .replaceAll('to-do', 'todo')
        .replaceAll('i-delete', 'idelete')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final List<String> tokens = cleaned.isEmpty
        ? <String>[]
        : cleaned.split(' ');
    final Set<String> tokenSet = tokens.toSet();

    final AssistantLanguage language = tokenSet.any(_taglishTokens.contains)
        ? AssistantLanguage.taglish
        : AssistantLanguage.english;

    if (cleaned.isEmpty) {
      return ParsedAssistantQuery(
        rawQuery: rawInput,
        normalizedQuery: cleaned,
        intent: AssistantIntent.unsupported,
        language: language,
      );
    }

    if (_isMutationCommand(cleaned, tokens, tokenSet)) {
      return ParsedAssistantQuery(
        rawQuery: rawInput,
        normalizedQuery: cleaned,
        intent: AssistantIntent.unsupported,
        language: language,
      );
    }

    final AssistantIntent intent = _classifyIntent(cleaned, tokenSet);
    return ParsedAssistantQuery(
      rawQuery: rawInput,
      normalizedQuery: cleaned,
      intent: intent,
      language: language,
    );
  }

  static bool _isMutationCommand(
    String cleaned,
    List<String> tokens,
    Set<String> tokenSet,
  ) {
    if (tokens.isEmpty) {
      return false;
    }
    final String first = tokens.first;
    if (_mutationVerbs.contains(first) || first == 'pay') {
      return true;
    }
    const List<String> explicitActionPhrases = <String>[
      'can you add',
      'can you create',
      'can you delete',
      'can you remove',
      'can you update',
      'can you edit',
      'can you pay',
      'can you mark',
      'please add',
      'please create',
      'please delete',
      'please pay',
      'please mark',
      'add expense',
      'add task',
      'create task',
      'delete task',
      'pay my bill',
      'mark as paid',
      'bayaran mo',
      'burahin mo',
      'magdagdag ka',
    ];
    for (final String phrase in explicitActionPhrases) {
      if (cleaned.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  static AssistantIntent _classifyIntent(String cleaned, Set<String> tokenSet) {
    final bool hasBillWord =
        tokenSet.any(_billTokens.contains) ||
        cleaned.contains('due soon') ||
        cleaned.contains('upcoming payment') ||
        cleaned.contains('unpaid payment');

    final bool hasDocWord = tokenSet.any(_docTokens.contains);

    // 1. Safe to Spend & financial allowance queries
    final bool asksSafeToSpend =
        cleaned.contains('safe to spend') ||
        cleaned.contains('safely spend') ||
        cleaned.contains('available balance') ||
        cleaned.contains('monthly budget') ||
        cleaned.contains('pera ko') ||
        tokenSet.contains('spendable') ||
        tokenSet.contains('badyet') ||
        (!hasBillWord &&
            (tokenSet.contains('magkano') ||
                tokenSet.contains('budget') ||
                tokenSet.contains('balance') ||
                tokenSet.contains('spend')));
    if (asksSafeToSpend) {
      return AssistantIntent.safeToSpend;
    }

    // 2. Overdue tasks (avoid stealing "overdue bills" or "expired docs")
    final bool hasOverdueWord =
        tokenSet.any(_overdueTokens.contains) || cleaned.contains('past due');
    if (hasOverdueWord && !hasBillWord && !hasDocWord) {
      return AssistantIntent.overdueTasks;
    }

    // 3. Bills due soon / unpaid obligations
    if (hasBillWord) {
      return AssistantIntent.billsDueSoon;
    }

    // 4. Expiring / expired documents
    final bool asksExpiringDocs =
        hasDocWord ||
        tokenSet.contains('expiring') ||
        tokenSet.contains('expired') ||
        tokenSet.contains('expiration') ||
        tokenSet.contains('expire');
    if (asksExpiringDocs) {
      return AssistantIntent.expiringDocuments;
    }

    // 5. Daily routines & streaks
    final bool asksRoutines =
        tokenSet.contains('routine') ||
        tokenSet.contains('routines') ||
        tokenSet.contains('habit') ||
        tokenSet.contains('habits') ||
        tokenSet.contains('streak') ||
        tokenSet.contains('streaks') ||
        cleaned.contains('keeping up');
    if (asksRoutines) {
      return AssistantIntent.routinesStatus;
    }

    // 6. Full day summary
    final bool asksSummary =
        tokenSet.contains('summarize') ||
        tokenSet.contains('summary') ||
        tokenSet.contains('recap') ||
        tokenSet.contains('briefing') ||
        tokenSet.contains('overview') ||
        tokenSet.contains('ibuod') ||
        tokenSet.contains('buod') ||
        cleaned.contains('brief me') ||
        cleaned.contains('how is my day') ||
        cleaned.contains('kamusta araw') ||
        cleaned.contains('kumusta araw') ||
        cleaned.contains('status ng araw');
    if (asksSummary) {
      return AssistantIntent.summarizeDay;
    }

    // 7. Focus / priorities / most important item
    final bool asksFocus =
        tokenSet.contains('focus') ||
        tokenSet.contains('priority') ||
        tokenSet.contains('priorities') ||
        tokenSet.contains('unahin') ||
        tokenSet.contains('pokus') ||
        cleaned.contains('most important') ||
        cleaned.contains('top task') ||
        cleaned.contains('what matters') ||
        cleaned.contains('focus on next');
    if (asksFocus) {
      return AssistantIntent.focusToday;
    }

    // 8. Today's tasks
    final bool asksTasksToday =
        tokenSet.contains('task') ||
        tokenSet.contains('tasks') ||
        tokenSet.contains('todo') ||
        tokenSet.contains('gawain') ||
        cleaned.contains('what should i do') ||
        cleaned.contains('what do i have to do') ||
        cleaned.contains('ano gagawin') ||
        cleaned.contains('anong gagawin');
    if (asksTasksToday) {
      return AssistantIntent.tasksToday;
    }

    return AssistantIntent.unsupported;
  }
}
