/// Input validation rules for Phase 8 Smart Assistant prompts.
abstract final class AssistantValidators {
  static const int maxPromptLength = 300;

  /// Validates user-submitted natural-language questions for KAYA Assistant.
  static String? validatePrompt(String? raw) {
    final String trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Please type a question for KAYA.';
    }
    if (trimmed.length > maxPromptLength) {
      return 'Keep your question under $maxPromptLength characters.';
    }
    return null;
  }
}
