import 'package:kaya/core/validation/task_validators.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_models.dart';

/// Validates and sanitizes structured AI responses before displaying them or
/// offering user-confirmed task proposals.
///
/// Returns `null` when a response is empty, malformed, or violates safety rules,
/// signaling [AssistantController] to fall back deterministically.
abstract final class AiResponseValidator {
  static const int maxReplyLength = 1200;
  static const int maxDetailLines = 8;
  static const int maxDetailLineLength = 220;
  static const int maxSuggestedTasks = 5;

  static final RegExp _disallowedControlChars = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

  static AiGatewayResponse? validate(AiGatewayResponse raw) {
    final String cleanReply = raw.replyText
        .replaceAll(_disallowedControlChars, '')
        .trim();
    if (cleanReply.isEmpty) {
      return null;
    }

    final String boundedReply = cleanReply.length > maxReplyLength
        ? '${cleanReply.substring(0, maxReplyLength - 1)}…'
        : cleanReply;

    final List<String> validDetails = <String>[];
    for (final String line in raw.details) {
      if (validDetails.length >= maxDetailLines) {
        break;
      }
      final String clean = line.replaceAll(_disallowedControlChars, '').trim();
      if (clean.isEmpty) {
        continue;
      }
      validDetails.add(
        clean.length > maxDetailLineLength
            ? '${clean.substring(0, maxDetailLineLength - 1)}…'
            : clean,
      );
    }

    final List<AiTaskSuggestion> validTasks = <AiTaskSuggestion>[];
    final Set<String> seenTitles = <String>{};
    for (final AiTaskSuggestion suggestion in raw.suggestedTasks) {
      if (validTasks.length >= maxSuggestedTasks) {
        break;
      }
      final String cleanTitle = suggestion.title
          .replaceAll(_disallowedControlChars, '')
          .trim();
      if (TaskValidators.validateTitle(cleanTitle) != null) {
        continue;
      }
      if (TaskValidators.validateDueDate(suggestion.dueDate) != null) {
        continue;
      }
      final String lower = cleanTitle.toLowerCase();
      if (!seenTitles.add(lower)) {
        continue;
      }
      validTasks.add(
        AiTaskSuggestion(
          id: suggestion.id.trim().isEmpty
              ? 'ai_task_${validTasks.length + 1}'
              : suggestion.id.trim(),
          title: cleanTitle,
          priority: suggestion.priority,
          category: suggestion.category,
          dueDate: suggestion.dueDate,
        ),
      );
    }

    return AiGatewayResponse(
      replyText: boundedReply,
      details: List<String>.unmodifiable(validDetails),
      suggestedTasks: List<AiTaskSuggestion>.unmodifiable(validTasks),
      estimatedTokens: raw.estimatedTokens < 0 ? 0 : raw.estimatedTokens,
      providerLabel: raw.providerLabel.trim().isEmpty
          ? 'KAYA Cloud AI'
          : raw.providerLabel.trim(),
    );
  }
}
