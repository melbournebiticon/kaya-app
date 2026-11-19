import 'package:kaya/core/errors/auth_failure.dart';
import 'package:kaya/core/utils/kaya_date_only.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_gateway.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_models.dart';
import 'package:kaya/features/assistant/domain/assistant_models.dart';
import 'package:kaya/features/tasks/domain/task_enums.dart';

/// Deterministic offline AI gateway used for local workspace mode and
/// automated Phase 9 testing (including failure & validation fallback tests).
class LocalStubAiAssistantGateway implements AiAssistantGateway {
  LocalStubAiAssistantGateway();

  bool simulateFailure = false;
  bool simulateInvalidResponse = false;

  @override
  Future<AiGatewayResponse> generateAssistance({
    required String authenticatedUserId,
    required AiGatewayRequest request,
  }) async {
    if (authenticatedUserId.trim().isEmpty) {
      throw AuthFailure.unauthorizedAccess();
    }
    if (simulateFailure) {
      throw AuthFailure.network('Simulated AI provider outage.');
    }
    if (simulateInvalidResponse) {
      return const AiGatewayResponse(replyText: '   ');
    }

    final String lower = request.prompt.toLowerCase();
    final bool isTaglish = request.language == AssistantLanguage.taglish;
    final KayaDateOnly? today = KayaDateOnly.tryParse(
      request.minimizedContext.referenceDateIso,
    );

    final bool asksPlan =
        lower.contains('plan') ||
        lower.contains('plano') ||
        lower.contains('break down') ||
        lower.contains('breakdown') ||
        lower.contains('schedule') ||
        lower.contains('organize') ||
        lower.contains('steps');

    if (asksPlan) {
      final int overdueCount =
          request.minimizedContext.taskSummary['overdueCount'] as int? ?? 0;
      final int todayCount =
          request.minimizedContext.taskSummary['todayCount'] as int? ?? 0;

      final List<AiTaskSuggestion> suggestions = <AiTaskSuggestion>[
        AiTaskSuggestion(
          id: 'plan_step_1',
          title: overdueCount > 0
              ? 'Clear top overdue priority first (25m focus block)'
              : 'Pick your #1 priority and work 25m distraction-free',
          priority: TaskPriority.high,
          category: TaskCategory.work,
          dueDate: today,
        ),
        AiTaskSuggestion(
          id: 'plan_step_2',
          title: 'Review today’s checklist & quick 5-minute errands',
          priority: TaskPriority.medium,
          category: TaskCategory.personal,
          dueDate: today,
        ),
      ];

      final String reply = isTaglish
          ? 'Heto ang simpleng action plan base sa minimized KAYA context mo ($overdueCount overdue, $todayCount due today). Walang mababago hanggang i-confirm mo:'
          : 'Here is a focused task plan based on your minimized KAYA context ($overdueCount overdue, $todayCount due today). Nothing is added until you confirm:';

      final List<String> details = <String>[
        '• Focus block 1: Tackle your highest-urgency item before new tasks.',
        '• Focus block 2: Batch small administrative items together.',
        if (request.minimizedContext.financialSummary != null)
          '• Financial cushion shared: ${request.minimizedContext.financialSummary!['safeToSpend'] ?? 'Not configured'}.',
      ];

      return AiGatewayResponse(
        replyText: reply,
        details: details,
        suggestedTasks: suggestions,
        estimatedTokens: 180,
        providerLabel: 'KAYA AI Planner (Local)',
      );
    }

    final List<String> details = <String>[
      '• Tasks in minimized context: ${request.minimizedContext.taskSummary['todayCount'] ?? 0} due today, ${request.minimizedContext.taskSummary['overdueCount'] ?? 0} overdue.',
      '• Routines today: ${request.minimizedContext.routineSummary['completedToday'] ?? 0}/${request.minimizedContext.routineSummary['scheduledToday'] ?? 0} completed.',
      if (request.minimizedContext.financialSummary != null)
        '• Financial summary shared (opted in): ${request.minimizedContext.financialSummary!['safeToSpend'] ?? 'No activity yet'}.'
      else
        '• Financial summary: Kept private (not shared with AI).',
    ];

    return AiGatewayResponse(
      replyText: isTaglish
          ? 'Base sa pinayagan mong minimized KAYA context, ito ang maikling AI overview para sa tanong mo:'
          : 'Based strictly on the minimized KAYA context you allowed, here is a concise overview for your question:',
      details: details,
      estimatedTokens: 140,
      providerLabel: 'KAYA AI (Local)',
    );
  }
}
