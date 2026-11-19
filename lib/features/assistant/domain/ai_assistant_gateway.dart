import 'package:kaya/features/assistant/domain/ai_assistant_models.dart';

/// Server-side AI provider gateway contract for Phase 9.
///
/// Security requirement: Flutter clients MUST never embed private AI API keys;
/// implementations forward requests to a secured backend (such as a Supabase
/// Edge Function).
abstract class AiAssistantGateway {
  Future<AiGatewayResponse> generateAssistance({
    required String authenticatedUserId,
    required AiGatewayRequest request,
  });
}
