import 'package:kaya/core/config/supabase_config.dart';
import 'package:kaya/features/assistant/data/local_stub_ai_assistant_gateway.dart';
import 'package:kaya/features/assistant/data/supabase_edge_ai_assistant_gateway.dart';
import 'package:kaya/features/assistant/domain/ai_assistant_gateway.dart';
import 'package:kaya/features/auth/data/in_memory_auth_profile_repository.dart';
import 'package:kaya/features/auth/data/supabase_auth_profile_repository.dart';
import 'package:kaya/features/auth/domain/auth_profile_repository.dart';
import 'package:kaya/features/bills/data/in_memory_bill_repository.dart';
import 'package:kaya/features/bills/data/supabase_bill_repository.dart';
import 'package:kaya/features/bills/domain/bill_repository.dart';
import 'package:kaya/features/life_vault/data/in_memory_life_vault_repository.dart';
import 'package:kaya/features/life_vault/data/supabase_life_vault_repository.dart';
import 'package:kaya/features/life_vault/domain/life_vault_repository.dart';
import 'package:kaya/features/money/data/in_memory_money_repository.dart';
import 'package:kaya/features/money/data/supabase_money_repository.dart';
import 'package:kaya/features/money/domain/money_repository.dart';
import 'package:kaya/features/reminders/data/in_memory_reminder_repository.dart';
import 'package:kaya/features/reminders/data/supabase_reminder_repository.dart';
import 'package:kaya/features/reminders/domain/reminder_repository.dart';
import 'package:kaya/features/routines/data/in_memory_life_organization_repository.dart';
import 'package:kaya/features/routines/data/supabase_life_organization_repository.dart';
import 'package:kaya/features/routines/domain/life_organization_repository.dart';
import 'package:kaya/features/tasks/data/in_memory_task_repository.dart';
import 'package:kaya/features/tasks/data/supabase_task_repository.dart';
import 'package:kaya/features/tasks/domain/task_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository bundle selected at startup (live Supabase when configured, or
/// isolated in-memory repositories for offline/test runs).
class KayaBackendRepositories {
  const KayaBackendRepositories({
    required this.authRepository,
    required this.taskRepository,
    required this.moneyRepository,
    required this.billRepository,
    required this.reminderRepository,
    required this.lifeVaultRepository,
    required this.lifeOrganizationRepository,
    required this.aiAssistantGateway,
    required this.isLiveSupabase,
    this.configurationError,
  });

  final AuthProfileRepository authRepository;
  final TaskRepository taskRepository;
  final MoneyRepository moneyRepository;
  final BillRepository billRepository;
  final ReminderRepository reminderRepository;
  final LifeVaultRepository lifeVaultRepository;
  final LifeOrganizationRepository lifeOrganizationRepository;
  final AiAssistantGateway aiAssistantGateway;
  final bool isLiveSupabase;
  final String? configurationError;

  factory KayaBackendRepositories.inMemory({String? configurationError}) {
    return KayaBackendRepositories(
      authRepository: InMemoryAuthProfileRepository(),
      taskRepository: InMemoryTaskRepository(),
      moneyRepository: InMemoryMoneyRepository(),
      billRepository: InMemoryBillRepository(),
      reminderRepository: InMemoryReminderRepository(),
      lifeVaultRepository: InMemoryLifeVaultRepository(),
      lifeOrganizationRepository: InMemoryLifeOrganizationRepository(),
      aiAssistantGateway: LocalStubAiAssistantGateway(),
      isLiveSupabase: false,
      configurationError: configurationError,
    );
  }

  /// Initializes Supabase from `--dart-define` / `--dart-define-from-file`
  /// environment variables and returns live repositories if valid.
  static Future<KayaBackendRepositories> initializeFromEnvironment() async {
    final SupabaseConfig config = SupabaseConfig.fromEnvironment();
    if (!config.isConfigured) {
      return KayaBackendRepositories.inMemory();
    }
    if (!config.isClientSafeKey) {
      return KayaBackendRepositories.inMemory(
        configurationError: 'Rejected unsafe Supabase key. Use only a publishable or anon key in client builds.',
      );
    }

    try {
      await Supabase.initialize(
        url: config.normalizedUrl,
        publishableKey: config.anonKey.trim(),
      );
      final SupabaseClient client = Supabase.instance.client;
      return KayaBackendRepositories(
        authRepository: SupabaseAuthProfileRepository(client: client),
        taskRepository: SupabaseTaskRepository(client: client),
        moneyRepository: SupabaseMoneyRepository(client: client),
        billRepository: SupabaseBillRepository(client: client),
        reminderRepository: SupabaseReminderRepository(client: client),
        lifeVaultRepository: SupabaseLifeVaultRepository(client: client),
        lifeOrganizationRepository: SupabaseLifeOrganizationRepository(
          client: client,
        ),
        aiAssistantGateway: SupabaseEdgeAiAssistantGateway(client: client),
        isLiveSupabase: true,
      );
    } catch (_) {
      return KayaBackendRepositories.inMemory(
        configurationError: 'Unable to initialize Supabase connection. Falling back to local workspace.',
      );
    }
  }
}
