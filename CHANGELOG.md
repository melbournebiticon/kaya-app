# Changelog

All notable changes to the **KAYA** project will be documented in this file.

## [0.10.0] - 2026-11-19 — Phase 10: Notifications & Automation

### Added
- **Android Manifest Permissions (`android/app/src/main/AndroidManifest.xml`):**
  - Added `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` permissions for Android local reminders.
- **Database Migration (`supabase/migrations/20261114000008_phase10_notifications.sql`):**
  - Created RLS-enforced `public.notification_preferences` table storing per-user toggles, reminder times, advance lead days, and quiet hours.
- **Deterministic Notification Engine, Quiet Hours & Gateway (`lib/features/notifications/`):**
  - Implemented `NotificationPermissionStatus`, `KayaNotificationChannel`, `QuietHoursWindow` (overnight & same-day deferral), `NotificationPreferences`, `ScheduledKayaNotification` (redacted `toString()`), `NotificationScheduleEngine` (stable FNV-1a ID deduplication, excludes completed tasks & paid bills, recurring weekly routines, privacy-safe document alerts), `LocalNotificationGateway`, `InMemoryLocalNotificationGateway`, and `NotificationController`.
- **Settings UI & App Shell Integration (`NotificationsSettingsCard`, `SettingsScreen`, `KayaAppShell`, `KayaApp`):**
  - Added permission explanation & request flow, master enable/disable switch, per-category toggles, Quiet Hours toggle, and active scheduled alert preview inside `SettingsScreen`.
  - Wired immediate cancellation of all scheduled alerts on disable or logout.
- **Automated Tests (`test/features/notifications/`):**
  - Added `notification_scheduler_and_security_test.dart` (quiet hours shifting, zero duplicates across repeated syncs, paid/completed exclusion, privacy redaction, permission gating, disable & logout cancellation) and `notifications_widget_test.dart`.

## [0.9.0] - 2026-11-19 — Phase 9: AI Integration

### Added
- **Server-Side AI Backend & Usage Controls (`supabase/migrations/20261114000007_phase9_ai_usage_controls.sql`, `supabase/functions/kaya-ai-assistant/index.ts`):**
  - Created RLS-enforced `public.ai_usage_daily` table for per-user daily AI request and token tracking.
  - Added Supabase Edge Function `kaya-ai-assistant` verifying Supabase JWTs, enforcing daily request limits (`25/day`) and `maxOutputTokens: 512`, calling Gemini strictly server-side using `GEMINI_API_KEY` (zero keys in Flutter), and returning validated structured JSON.
- **Privacy Minimization, Consent & Response Validation (`lib/features/assistant/domain/`):**
  - Added `AiConsentSettings`, `AiUsageQuota`, `AiTaskSuggestion`, `AiMinimizedContextPayload`, `AiContextMinimizer` (strips IDs, notes, locations, and raw transactions; blocks financial & document summaries unless explicitly opted in), `AiResponseValidator`, and `AiAssistantGateway`.
- **Gateways, Controller & UI (`lib/features/assistant/`, `supabase_bootstrap.dart`, `app.dart`):**
  - Implemented `SupabaseEdgeAiAssistantGateway` and offline `LocalStubAiAssistantGateway`.
  - Extended `AssistantController` with `askSmart(...)`, per-user quota tracking, automatic deterministic fallback on outage/validation error/quota exhaustion, confirmed task creation (`confirmTaskSuggestion`), and logout consent/quota reset.
  - Updated `AssistantScreen` with optional AI toggle (OFF by default), Privacy & Limits consent dialog, source/fallback badges, and confirmed task-suggestion cards (`KayaConfirmDialog`).
- **Automated Tests (`test/features/assistant/`):**
  - Added `ai_integration_security_test.dart` (data minimization, opt-in consent, validation, quota enforcement, outage/invalid fallback, confirmed task creation, logout reset) and `ai_integration_widget_test.dart`.

## [0.8.1] - 2026-11-19 — Live Supabase Backend Integration

### Added
- **Supabase Flutter SDK & Safe Environment Config (`pubspec.yaml`, `.env.example.json`, `.gitignore`, `lib/core/config/supabase_config.dart`, `lib/core/config/supabase_bootstrap.dart`):**
  - Added `supabase_flutter: ^2.18.3`.
  - Added `SupabaseConfig.normalizedUrl` (strips `/rest/v1/` and trailing slashes), gitignored local `.env.json`, committed `.env.example.json` template, and `KayaBackendRepositories.initializeFromEnvironment()` with fail-closed key validation.
- **Shared Error Mapper & All 7 Live Supabase Repositories (`lib/core/data/supabase_error_mapper.dart`, `lib/features/*/data/supabase_*_repository.dart`):**
  - Implemented `SupabaseAuthProfileRepository`, `SupabaseTaskRepository`, `SupabaseMoneyRepository`, `SupabaseBillRepository` (with non-duplicating recurring cycle spawning), `SupabaseReminderRepository`, `SupabaseLifeVaultRepository`, and `SupabaseLifeOrganizationRepository`.
- **App Entrypoint Wiring (`lib/main.dart`, `lib/app/app.dart`):**
  - Wired `KayaBackendRepositories` initialization in `main()` and repository injection in `KayaApp` while preserving offline `InMemory*Repository` testability.
- **Unit Tests (`test/core/supabase_config_and_mapper_test.dart`):**
  - Verified URL normalization, `sb_secret_` / `service_role` rejection, safe Auth/Postgrest error mapping, and date-only parsing.

### Fixed
- **SQL Migration Triggers & RLS Hygiene (`supabase/migrations/`):**
  - Added `tg_op = 'INSERT'` guards in `20261114000002_phase3_tasks.sql`, `20261114000004_phase5_bills_and_reminders.sql`, and `20261114000005_phase6_life_vault.sql` so inserts with completed/paid/returned flags never reference unassigned `old` records.
  - Qualified `routine_step_completions.routine_id` in `20261114000006_phase7_life_organization.sql`.

## [0.8.0] - 2026-11-19 — Phase 8: Smart Assistant Foundation

### Added
- **Prompt Validation & Domain Models (`lib/core/validation/assistant_validators.dart`, `lib/features/assistant/domain/`):**
  - Added `AssistantValidators.validatePrompt` enforcing trimmed non-empty input within 300 characters.
  - Added `AssistantIntent`, `AssistantLanguage` (`english`, `taglish`), `DomainReadState<T>`, `AssistantUrgentItem`, `AssistantDailyInsight`, `AssistantMessage` (with log-redacted `toString()`), and `AssistantContextSnapshot`.
- **Deterministic English & Taglish Intent Parser (`assistant_intent_parser.dart`):**
  - Implemented offline keyword/phrase routing supporting all Phase 8 blueprint queries (`tasksToday`, `overdueTasks`, `billsDueSoon`, `safeToSpend`, `expiringDocuments`, `routinesStatus`, `focusToday`, `summarizeDay`) and safely blocking mutation/out-of-scope prompts as `AssistantIntent.unsupported`.
- **Urgency Ranker & Grounded Response Engine (`assistant_urgency_ranker.dart`, `assistant_response_engine.dart`):**
  - Built cross-domain priority ranking (`AssistantUrgencyRanker`) and Daily Insights generation from verified records only.
  - Reused `MoneyController.currentOverview` / `SafeToSpendCalculator` directly for financial answers, strictly excluded paid bills from due-soon totals, redacted private Life Vault notes, and guarded `!isReady` domains (`failed`, `loading`, `unauthenticated`) against falling through to empty results.
- **Account-Isolated Context Builder & Controller (`assistant_context_builder.dart`, `assistant_controller.dart`):**
  - Enforced owner verification (`ctrl.activeUserId == uid`) on every domain slice, immediate conversation wiping on `bindAuthenticatedUser(null)` or account switches, and targeted `retryFailedData()` reloads.
- **UI & Shell Integration (`AssistantScreen`, `KayaAppShell`, `KayaApp`):**
  - Updated `AssistantScreen` with Daily Insights cards, clickable English/Taglish suggested prompt chips, in-memory conversation bubbles, Clear button, retrieval failure Retry controls, and sticky bottom prompt composer.
  - Wired `AssistantController` lifecycle, shared listenables, and logout clearing inside `KayaApp` and `KayaAppShell`.
- **Automated Tests (`test/features/assistant/`):**
  - Added deterministic parser, grounded data, Safe to Spend reuse, retrieval-failure vs empty-data distinction, cross-account isolation, logout cache clearing, and log-redaction unit tests (`assistant_engine_and_security_test.dart`) plus end-to-end UI and retry recovery widget tests (`assistant_widget_test.dart`).

## [0.7.0] - 2026-11-19 — Phase 7: Life Organization

### Added
- **Supabase Database Migration (`supabase/migrations/20261114000006_phase7_life_organization.sql`):**
  - Created 7 tables: `public.checklists`, `public.checklist_items`, `public.daily_routines`, `public.routine_steps`, `public.routine_step_completions`, `public.shopping_lists`, and `public.shopping_list_items`.
  - Enabled and forced Row Level Security (`RLS`) across all Phase 7 tables bound to `(select auth.uid()) = user_id` and parent ownership checks.
- **Validation & Date Helpers (`lib/core/validation/life_organization_validators.dart`, `lib/core/utils/kaya_date_only.dart`):**
  - Added `LifeOrganizationValidators` for titles, scheduled weekday sets, positive integer quantities, and non-negative minor-unit unit prices.
  - Added `KayaDateOnly.weekday` for deterministic calendar weekday evaluation.
- **Smart Checklists (`lib/features/checklists/`):**
  - Implemented `SmartChecklist` and `ChecklistItemEntry` domain models with `progressRatio`, `progressLabel`, and `hasCompletedItems`.
  - Built `ChecklistsWorkspaceSection` supporting create/delete checklist, inline add/toggle/delete item, progress bar, and confirmed reset of completed items.
- **Daily Routines (`lib/features/routines/`):**
  - Implemented `DailyRoutine`, `RoutineStep`, and `RoutineWeekday` (`Mon`–`Sun`) with scheduled-day filtering, daily step completions, and accurate `currentStreak` calculation that skips unscheduled rest days without breaking streaks.
  - Implemented `LifeOrganizationRepository`, `InMemoryLifeOrganizationRepository` (with strict per-user ownership isolation), `LifeOrganizationController` (with session restoration and logout cache clearing), and `RoutinesWorkspaceSection`.
- **Shopping Lists (`lib/features/shopping/`):**
  - Implemented `ShoppingList`, `ShoppingProductItem`, and `ShoppingUnit` using integer minor currency units (`estimatedUnitPriceMinor`) for exact `estimatedTotalMinor`, `purchasedTotalMinor`, and `remainingTotalMinor` sums.
  - Built `ShoppingWorkspaceSection` keeping shopping estimates completely separate from actual `MoneyController` expenses.
- **Life & Today Integration (`LifeScreen`, `TodayScreen`, `KayaAppShell`, `KayaApp`):**
  - Added `Routines`, `Checklists`, and `Shopping` sub-tabs in `LifeScreen` and `today_routines_badge` in `TodayScreen`, wired with `LifeOrganizationController` in `App` and `AppShell`.
- **Automated Tests (`test/features/life_organization/`):**
  - Added domain/RLS unit tests (ownership isolation, scheduled weekday streaks, shopping estimate isolation from actual expenses) and end-to-end UI widget tests covering dialog creation, completion toggling, checklist reset, and totals.

## [0.6.1] - 2026-11-16 — UI Humanization & De-AI Polish Pass

### Changed
- **Life Workspace Sub-Tabs (`lib/features/life/presentation/life_screen.dart`):**
  - Replaced stacked vertical scrolling across all Life domains with focused sub-tabs (`Tasks`, `Bills & Reminders`, `Life Vault`, `All Areas`) so each workspace stays uncluttered.
- **Sleek Single-Row List Items & Reduced Boxy Borders (`KayaCard`, `KayaStatusBadge`, item tiles):**
  - Refined `KayaCard` to subtle hairline borders (`AppColors.borderSubtle`) and softened `KayaStatusBadge` padding/border opacity.
  - Replaced multi-badge item card footers with quiet single-level rows using inline icon + status text metadata across `TaskCardTile`, `TransactionCardTile`, `BillCardTile`, `ReminderCardTile`, `VaultDocumentCardTile`, and `BelongingCardTile`.
  - Removed redundant card wrappers and heavy badge clusters in `TasksWorkspaceSection`, `BillsRemindersWorkspaceSection`, and `LifeVaultWorkspaceSection`.
- **Natural Copywriting & Editorial Headers (`TodayScreen`, `MoneyScreen`, `CanIBuyThisCard`, `AssistantScreen`, `SettingsScreen`, `KayaAppShell`):**
  - Removed technical/AI jargon (e.g., `"Safe to Spend Engine"`, `"Centralized Financial Clarity"`, `"Estimate Only • Not Recorded as Expense"` badge) in favor of calm, human-crafted typography and contextual status indicators.

## [0.6.0] - 2026-11-16 — Phase 6: Life Vault

### Added
- **Supabase Database Migration (`supabase/migrations/20261114000005_phase6_life_vault.sql`):**
  - Created `public.vault_documents` (`category`, `physical_location`, date-only `issue_date` and `expiration_date` with `expiration_date >= issue_date` check) and `public.personal_belongings` (`category`, `storage_location`, `custody_type`, `counterparty_name`, `due_return_date`, `is_returned`).
  - Enabled and forced Row Level Security (`RLS`) on both tables with least-privilege policies bound to `(select auth.uid()) = user_id`.
- **Privacy Redaction & Validation (`lib/core/validation/life_vault_validators.dart`, `VaultDocument`, `BelongingItem`):**
  - Enforced date-order validation, required physical/storage locations, and conditional counterparty validation for borrowed/lent items.
  - Redacted sensitive document titles, physical locations, notes, and counterparty names in `VaultDocument.toString()` and `BelongingItem.toString()` so private data is never exposed in logs.
- **Life Vault Domain, Repository, Controller & UI (`lib/features/life_vault/`, `LifeScreen`, `TodayScreen`, `KayaApp`):**
  - Implemented accurate `DocumentExpirationStatus` (`expired`, `expiringSoon` within 30 days, `valid`, `noExpiration`), RLS-enforcing `InMemoryLifeVaultRepository`, and session-bound `LifeVaultController`.
  - Built `LifeVaultWorkspaceSection`, `VaultDocumentFormDialog`, `VaultDocumentCardTile`, `BelongingFormDialog`, and `BelongingCardTile` (with confirmed return/reopen + `Undo` SnackBar and confirmed delete).
  - Integrated expiring/expired document alerts (`today_expiring_docs_badge`) into `TodayScreen` and live vault stats into `LifeScreen`.
- **Automated Tests (`test/features/life_vault/`):**
  - Added unit, expiration accuracy, log redaction privacy, RLS/logout isolation, and full widget workflow tests.

## [0.5.0] - 2026-11-16 — Phase 5: Bills & Reminders

### Added
- **Supabase Database Migration (`supabase/migrations/20261114000004_phase5_bills_and_reminders.sql`):**
  - Created `public.bills` (`amount_minor bigint`, `category`, `recurrence`, `recurrence_group_id`, `due_date date`, `is_paid`, unique `(user_id, recurrence_group_id, due_date)` constraint preventing duplicate recurring bill generation) and `public.reminders` (`title`, `notes`, `due_date date`, `is_completed`).
  - Enabled and forced Row Level Security (`RLS`) on both tables with least-privilege policies bound to `(select auth.uid()) = user_id`.
- **Calendar Date Recurrence & Validation (`lib/core/utils/kaya_date_only.dart`, `lib/core/validation/bill_reminder_validators.dart`):**
  - Added leap-year and end-of-month clamping `KayaDateOnly.addMonths` and `addYears` helpers.
  - Added `BillReminderValidators` matching client and database constraints.
- **Bills & Reminders Domain, Repositories & Controllers (`lib/features/bills/`, `lib/features/reminders/`):**
  - Implemented `BillItem`, `BillCategory`, `BillRecurrence`, `BillFilterView`, RLS-enforcing `InMemoryBillRepository` (with atomic non-duplicating next-cycle spawning when marking recurring bills paid), and `BillController`.
  - Implemented `ReminderItem`, `ReminderFilterView`, RLS-enforcing `InMemoryReminderRepository`, and `ReminderController`.
- **Centralized Safe to Spend, Life & Today Integration (`MoneyController`, `MoneyScreen`, `LifeScreen`, `TodayScreen`, `KayaApp`):**
  - Connected `MoneyController.bindUnpaidObligationsSource` to `BillController.unpaidObligationsMinorForPeriod` so unpaid bills reduce `Safe to Spend` via the single centralized `SafeToSpendCalculator` and paid bills are excluded immediately.
  - Built `BillsRemindersWorkspaceSection`, `BillFormDialog`, `BillCardTile`, `ReminderFormDialog`, and `ReminderCardTile` with confirmation dialogs (including early-completion/early-payment warnings for upcoming items), `Undo` SnackBars, and confirmed destructive deletes.
  - Integrated overdue/due-today bills, reminders, and upcoming bills badge into `TodayScreen`.
- **Automated Tests (`test/features/bills/`):**
  - Added unit, leap-year recurrence clamping, non-duplication, centralized `Safe to Spend` exclusion, RLS/logout isolation, and end-to-end widget tests.

## [0.4.0] - 2026-11-15 — Phase 4: Money Management

### Added
- **Supabase Database Migration (`supabase/migrations/20261114000003_phase4_money.sql`):**
  - Created `public.money_transactions` (`amount_minor bigint`, `type`, `category`, `currency`, `transaction_date date`) and `public.monthly_budgets` (`overall_limit_minor bigint`, unique `(user_id, year, month, currency)`) with server-side `CHECK` constraints and triggers.
  - Enabled and forced Row Level Security (`RLS`) on both tables with least-privilege policies bound to `(select auth.uid()) = user_id`.
- **Decimal-Safe Formatting & Validation (`lib/features/money/domain/money_formatter.dart`, `lib/core/validation/money_validators.dart`):**
  - Implemented `MoneyFormatter` parsing/formatting strictly via integer minor currency units (`PHP` 2 decimals, `JPY` 0 decimals, etc.) without binary floating-point arithmetic.
  - Added `MoneyValidators` enforcing required descriptions/amounts, positive amounts, range bounds, and rejection of `NaN`, `Infinity`, negative values, and excess decimals.
- **Centralized Safe to Spend Engine & Money Domain (`lib/features/money/domain/`):**
  - Implemented `SafeToSpendCalculator.calculateOverview` and `SafeToSpendCalculator.evaluatePurchase` as the single authoritative formula source across the entire app (including `TodayScreen` and `MoneyScreen`).
  - Added `MoneyTransaction`, `MonthlyBudget`, `TransactionType`, `MoneyCategory`, and `TransactionFilterType`.
- **Repository, Controller & UI (`lib/features/money/`, `TodayScreen`, `KayaAppShell`, `KayaApp`):**
  - Implemented RLS-enforcing `InMemoryMoneyRepository` and session-bound `MoneyController` (with immediate private cache wiping on logout/account switch).
  - Built `MoneyScreen`, `TransactionFormDialog`, `MonthlyBudgetDialog`, `CanIBuyThisCard` (strictly estimate-only without modifying actual expenses), and `TransactionCardTile` (confirmed delete via `KayaConfirmDialog`).
  - Integrated live centralized `Safe to Spend` status badge into `TodayScreen`.
- **Automated Tests (`test/features/money/`):**
  - Added unit, validation, centralized calculator, and RLS/logout isolation tests plus full Money & Today widget workflow tests.

## [0.3.0] - 2026-11-14 — Phase 3: Task Management

### Added
- **Supabase Database Migration (`supabase/migrations/20261114000002_phase3_tasks.sql`):**
  - Created `public.tasks` table with `user_id` ownership, date-only `due_date date` column (separated from `timestamptz`), server-side `CHECK` constraints (`title` length `1..140`, `notes` length `<= 1000`, `priority` and `category` whitelists, `due_date` range check), and least-privilege `SELECT`, `INSERT`, `UPDATE`, `DELETE` RLS policies bound to `(select auth.uid()) = user_id`.
- **Date-Only Value Object (`lib/core/utils/kaya_date_only.dart`):**
  - `KayaDateOnly` calendar date value object preventing timezone midnight drift when evaluating `overdue`, `today`, and `upcoming` task buckets.
- **Task Domain, Validation, Repository & Controller (`lib/features/tasks/`, `lib/core/validation/task_validators.dart`):**
  - `TaskPriority` (`low`, `medium`, `high`, `urgent`), `TaskCategory` (`personal`, `work`, `finance`, `health`, `home`, `errands`, `other`), `TaskDueBucket`, `TaskFilterView`, and `TaskItem` with deterministic urgency ranking (`compareByUrgency`).
  - `TaskRepository` and RLS-enforcing `InMemoryTaskRepository`.
  - `TaskController` with user session binding, logout cache clearing, search/filter state, duplicate-mutation locking, and separated loading/empty/error states with retry.
- **Task Management UI & Today Integration (`lib/features/tasks/presentation/`, `TodayScreen`, `LifeScreen`):**
  - `QuickAddTaskBar`, `TaskFormDialog` (Create/Edit), `TaskCardTile` (Confirmed Complete/Reopen with early-completion warning for upcoming tasks and Undo SnackBar, Edit, Confirmed Delete), and `TasksWorkspaceSection`.
  - Live integration with `TodayScreen` (`Most Important Task` highlight, `QuickAddTaskBar`, and `Today's Priority Queue`).
- **Automated Tests (`test/features/tasks/`):**
  - Unit tests for `KayaDateOnly` and `TaskValidators`, cross-account RLS isolation tests, urgency ranking tests, and full UI widget lifecycle tests (including accidental-tap cancellation, upcoming early-completion warning, and Undo SnackBar).

## [0.2.0] - 2026-11-14 — Phase 2: Authentication & User Profiles

### Added
- **Supabase Database Migration (`supabase/migrations/20261114000001_phase2_auth_and_profiles.sql`):**
  - Created `public.profiles` table with server-side `CHECK` constraints (`display_name` length `2..60`, `email` length `5..254`, `preferred_currency` whitelist).
  - Enabled and forced Row Level Security (`RLS`) with least-privilege `SELECT`, `INSERT`, `UPDATE`, and `DELETE` policies strictly bound to `(select auth.uid()) = id`.
  - Added automatic `auth.users` signup provisioning trigger and `updated_at` timestamp trigger.
- **Security & Configuration (`lib/core/config/supabase_config.dart`, `lib/core/errors/auth_failure.dart`):**
  - Environment-based configuration via `--dart-define=SUPABASE_URL` and `--dart-define=SUPABASE_ANON_KEY`.
  - Fail-closed `isClientSafeKey` guard that rejects `service_role` JWTs and secret keys in client builds.
  - Token redaction in `AuthSession.toString()` so tokens are never printed in logs.
- **Input Validation (`lib/core/validation/auth_validators.dart`):**
  - Client and repository-level validators for email, password complexity, password confirmation, display name, and currency codes.
- **Authentication & Profile Domain/Application/UI (`lib/features/auth/`):**
  - `SupportedCurrency` (`PHP`, `USD`, `EUR`, `SGD`, `JPY`, `AUD`, `GBP`, `CAD`) with minor-unit metadata.
  - `UserProfile`, `AuthSession`, `AuthProfileRepository`, and RLS-enforcing `InMemoryAuthProfileRepository`.
  - `AuthController` with duplicate-submission locking, stale-request epoch protection, session restoration, and immediate private cache wiping on logout.
  - `KayaAuthScreen` (Sign In, Create Account, Password Recovery) and `ProfileSectionCard` (view/edit profile & currency, unsaved changes confirmation, and confirmed Sign Out).
- **Automated Security & Widget Tests (`test/features/auth/`):**
  - Boundary validation tests, cross-account RLS isolation tests (verifying User B cannot read or update User A's profile), session TTL expiration tests, and full UI registration/profile-edit/logout widget tests.

## [0.1.0] - 2026-11-14 — Phase 1: Project Foundation & Design System

### Added
- **Project Foundation:** Initialized clean Flutter application (`kaya`, `com.kaya.app`) targeting Android, Web, and Windows.
- **KAYA Design System (`lib/app/theme/`):**
  - `AppColors`: Dark-first palette (`#0D1117` background, `#151B23` surface, `#6EE7B7` primary, `#7DD3FC` secondary) with WCAG-compliant text contrast and semantic status tokens.
  - `AppSpacing`: 4pt/8pt spatial scale, border radius tokens, 48px minimum accessible touch targets, and responsive max-width constraints.
  - `AppTypography`: Readable sans-serif hierarchy with accessible minimum font sizes.
  - `AppTheme`: Material 3 dark theme configuration.
- **Responsive Layout Utilities (`lib/core/utils/responsive_layout.dart`):**
  - Adaptive breakpoints (`compact`, `medium`, `expanded`) and `KayaResponsiveScaffoldBody`.
- **Reusable Core UI Components (`lib/core/widgets/`):**
  - `KayaButton` (Primary, Secondary, Outline, Ghost, Destructive variants with loading guard and minimum 48px height).
  - `KayaCard` (Surface container with subtle border and interactive semantics).
  - `KayaSectionHeader` (Consistent section title, subtitle, and trailing action layout).
  - `KayaStatusBadge` (Color + icon + text label to never rely on color alone).
  - `KayaLoadingState`, `KayaEmptyState`, `KayaErrorState` (with retry support), and `KayaConfirmDialog` (for destructive action confirmation).
- **Navigation & App Shell (`lib/app/router/`):**
  - `KayaAppShell` with preserved module state (`IndexedStack`), mobile `NavigationBar`, and tablet/desktop/web `NavigationRail` across all 6 core modules (`Today`, `Money`, `Life`, `Assistant`, `Analytics`, `Settings`).
- **Splash & Onboarding (`lib/features/splash/`, `lib/features/onboarding/`):**
  - Branded splash screen and 4-step interactive onboarding flow.
- **Automated Test Suite (`test/`):**
  - Unit and widget tests covering design tokens, responsive layout breakpoints, reusable UI components, onboarding flow, and app shell navigation.
