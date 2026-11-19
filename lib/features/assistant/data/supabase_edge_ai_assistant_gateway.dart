import 'package:kaya/core/data/supabase_error_mapper.dart';
import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_gateway.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_models.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-side AI gateway backed by the secured `kaya-ai-assistant` Supabase
/// Edge Function.
///
/// Security guarantee: zero private AI API keys exist in the Flutter app.
class SupabaseEdgeAiAssistantGateway implements AiAssistantGateway {
  SupabaseEdgeAiAssistantGateway({
    required this.client,
    this.functionName = 'kaya-ai-assistant',
  });

  final SupabaseClient client;
  final String functionName;

  @override
  Future<AiGatewayResponse> generateAssistance({
    required String authenticatedUserId,
    required AiGatewayRequest request,
  }) async {
    SupabaseErrorMapper.requireAuthenticatedUserId(
      client,
      expectedUserId: authenticatedUserId,
    );

    try {
      final FunctionResponse response = await client.functions.invoke(
        functionName,
        body: request.toJson(),
      );

      if (response.status == 429) {
        throw AuthFailure.validation('Daily AI usage limit reached.');
      }
      if (response.status != 200 || response.data is! Map) {
        throw AuthFailure.network(
          'AI assistant backend is currently unavailable.',
        );
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(
        response.data as Map,
      );
      final String replyText = (data['replyText'] as String? ?? '').trim();
      final List<dynamic> rawDetails =
          data['details'] as List<dynamic>? ?? const <dynamic>[];
      final List<String> details = rawDetails
          .whereType<String>()
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList(growable: false);

      final List<dynamic> rawTasks =
          data['suggestedTasks'] as List<dynamic>? ?? const <dynamic>[];
      final List<AiTaskSuggestion> suggestions = <AiTaskSuggestion>[];
      for (int i = 0; i < rawTasks.length; i++) {
        final dynamic item = rawTasks[i];
        if (item is! Map) {
          continue;
        }
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        final String title = (map['title'] as String? ?? '').trim();
        if (title.isEmpty) {
          continue;
        }
        suggestions.add(
          AiTaskSuggestion(
            id: 'edge_task_${i + 1}',
            title: title,
            priority:
                TaskPriority.tryFromId(map['priority'] as String?) ??
                TaskPriority.medium,
            category:
                TaskCategory.tryFromId(map['category'] as String?) ??
                TaskCategory.personal,
            dueDate: KayaDateOnly.tryParse(map['dueDate'] as String?),
          ),
        );
      }

      return AiGatewayResponse(
        replyText: replyText,
        details: details,
        suggestedTasks: suggestions,
        estimatedTokens: SupabaseErrorMapper.parseInt(data['estimatedTokens']),
        providerLabel: (data['providerLabel'] as String? ?? 'KAYA Cloud AI')
            .trim(),
      );
    } on AuthFailure {
      rethrow;
    } on FunctionException catch (e) {
      if (e.status == 429) {
        throw AuthFailure.validation('Daily AI usage limit reached.');
      }
      throw AuthFailure.network(
        'AI assistant backend is currently unavailable.',
      );
    } catch (_) {
      throw AuthFailure.network(
        'AI assistant backend is currently unavailable.',
      );
    }
  }
}
