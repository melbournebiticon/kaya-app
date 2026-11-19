# KAYA — Your Life, Clearer.
**MASTER PRODUCT BLUEPRINT & DEVELOPMENT RULEBOOK**

---

## 1. Product Vision — Ano ang KAYA?

Ang **KAYA** ay isang personal life-management application na pinagsasama ang iba't ibang bahagi ng buhay ng user sa isang organized at connected platform.

Hindi lang ito ordinaryong To-Do List o Budget Tracker. Layunin nitong maging personal operating system na tutulong sa user na pamahalaan ang kanyang:
- Daily activities at responsibilities.
- Income, expenses, at budgets.
- Bills at reminders.
- Documents at personal belongings.
- Routines at checklists.
- Shopping lists.
- Personal goals at progress.
- Daily decisions gamit ang KAYA Assistant.

**Main goal:** Bawasan ang mental clutter ng user at tulungan siyang malaman kung ano ang dapat gawin, ano ang kailangang bayaran, magkano ang available niyang pera, at ano ang dapat niyang pagtuunan ng pansin.

### Core questions na dapat masagot ng KAYA
1. What should I do today?
2. What is my most important task?
3. Do I have upcoming bills?
4. How much can I safely spend?
5. Are my documents expiring?
6. Am I keeping up with my routines?
7. What should I focus on next?

---

## 2. Product Areas

| Module | Main responsibility |
| :--- | :--- |
| **Today** | Daily overview at priorities |
| **Money** | Income, expenses, budgets, Safe to Spend |
| **Life** | Tasks, bills, documents, routines, belongings |
| **Assistant** | Personal assistant grounded in KAYA data |
| **Analytics** | Financial and personal progress |
| **Settings** | Account, preferences, privacy, security |

---

## 3. Complete Development Roadmap (14 Planned Phases)

### Phase 1 — Project Foundation & Design System
**Goal:** Gumawa ng stable, organized, at premium Flutter application foundation.

**Features and tasks:**
- Create clean Flutter project.
- Establish folder architecture.
- Configure Material 3.
- Establish KAYA design system.
- Create reusable UI components.
- Build app shell and navigation.
- Create onboarding flow.
- Implement splash/loading experience.
- Make responsive Android and web layouts.
- Establish typography, colors, spacing, and icon styles.
- Add accessibility foundations.
- Set up linting and testing.

**Acceptance criteria:**
- App launches successfully.
- Navigation works.
- Responsive layouts work.
- Reusable components follow shared design tokens.
- No major analyzer errors.
- Baseline tests pass.

---

### Phase 2 — Authentication & User Profiles
**Goal:** Secure user accounts and personal profiles.

**Features:**
- Registration.
- Login.
- Logout.
- Password recovery.
- Session restoration.
- User profile.
- Profile editing.
- Currency preferences.
- Supabase authentication.
- Row Level Security.

**Acceptance criteria:**
- Users can only access their own data.
- Session restoration works.
- Logout clears private information.
- Authentication errors are handled safely.

---

### Phase 3 — Task Management
**Goal:** Organize daily activities and responsibilities.

**Features:**
- Create, edit, delete tasks.
- Complete and reopen tasks.
- Due dates.
- Priority levels.
- Task categories.
- Today view.
- Upcoming tasks.
- Overdue tasks.
- Search and filters.
- Quick Add.

**Acceptance criteria:**
- Tasks persist correctly.
- Date calculations are accurate.
- User ownership is enforced.
- Loading, empty, and error states work.

---

### Phase 4 — Money Management
**Goal:** Give users an accurate view of their finances.

**Features:**
- Income tracking.
- Expense tracking.
- Categories.
- Monthly budgets.
- Available balance.
- Budget progress.
- Safe to Spend.
- Can I Buy This?
- Currency formatting.

**Important financial rule:**
- Use one centralized financial calculation. Never duplicate Safe to Spend formulas in multiple screens.
- Financial calculations must use a decimal-safe strategy or integer minor currency units.

**Acceptance criteria:**
- Accurate calculations.
- Correct budget deductions.
- No duplicate financial deductions.
- Actual transactions are separated from estimates.

---

### Phase 5 — Bills & Reminders
**Goal:** Prevent users from forgetting payments and important dates.

**Features:**
- Create and edit bills.
- Paid/unpaid status.
- Bill due dates.
- Bill categories.
- Recurring bills where supported.
- Create reminders.
- Complete/reopen reminders.
- Overdue and upcoming views.
- Today integration.

**Acceptance criteria:**
- Paid bills are excluded from unpaid obligations.
- Recurring entries do not duplicate.
- Dates are handled correctly.
- Safe to Spend uses the same established formula.

---

### Phase 6 — Life Vault
**Goal:** Organize important documents and personal belongings.

**Features:**
- Document management.
- Document categories.
- Issue dates.
- Expiration dates.
- Expiring-soon status.
- Physical document location.
- Personal item tracking.
- Borrowed/lent items.
- Return status.
- Search and filters.

**Acceptance criteria:**
- Private records are protected.
- Expiration dates are accurate.
- Sensitive document contents are not exposed in logs.
- Private file storage, if added, has proper authorization.

---

### Phase 7 — Life Organization
**Goal:** Help users organize routines and everyday activities.

**Features:**
- **Smart Checklists:**
  - Create checklists.
  - Add and manage checklist items.
  - Track progress.
  - Reset completed items.
- **Daily Routines:**
  - Create routines.
  - Configure scheduled days.
  - Add routine steps.
  - Track daily completion.
  - Calculate progress and streaks.
- **Shopping Lists:**
  - Create shopping lists.
  - Add products.
  - Quantity and unit.
  - Estimated unit price.
  - Purchased/unpurchased status.
  - Estimated total.
  - Remaining shopping total.

**Acceptance criteria:**
- Routine dates are correct.
- Shopping calculations are accurate.
- Estimated shopping costs are not automatically recorded as expenses.

---

### Phase 8 — Smart Assistant Foundation
**Goal:** Build a deterministic assistant using real KAYA data.

**Supported examples:**
- What are my tasks today?
- Ano tasks ko ngayon?
- May overdue tasks ba ako?
- What bills are due soon?
- Magkano safe to spend ko?
- Are my documents expiring?
- What should I focus on today?
- Summarize my day.

**Features:**
- English and Taglish intent parser.
- Context builder.
- Daily insights.
- Suggested questions.
- Urgency ranking.
- Safe unsupported-question responses.
- In-memory conversation.

**Acceptance criteria:**
- No fabricated data.
- Uses authenticated user's information.
- Reuses existing financial calculations.
- Distinguishes empty results from retrieval failures.
- Clears context after logout or account switching.

---

### Phase 9 — AI Integration
**Goal:** Add optional AI-powered natural-language assistance.

**Features:**
- AI provider integration.
- Secure backend.
- Context-aware conversations.
- Task planning assistance.
- Natural-language understanding.
- AI response validation.
- Usage limits.
- Cost controls.
- Deterministic fallback.

**Security requirements:**
- Never embed private AI API keys in Flutter.
- Use server-side provider requests.
- Minimize personal data sent to AI.
- Ask permission before sharing sensitive information.
- Require confirmation before AI changes records.

---

### Phase 10 — Notifications & Automation
**Goal:** Provide reliable reminders and recurring activities.

**Features:**
- Android local notifications.
- Task reminders.
- Bill reminders.
- Document expiration alerts.
- Routine reminders.
- Recurring schedules.
- Quiet hours.
- Notification preferences.
- Permission management.

**Acceptance criteria:**
- No duplicate notifications.
- Correct scheduling.
- Proper permission handling.
- Users can disable notifications.

---

### Phase 11 — Life Analytics
**Goal:** Help users understand their progress.

**Features:**
- Income and expenses analytics.
- Budget utilization.
- Spending categories.
- Task completion statistics.
- Routine consistency.
- Bill payment history.
- Monthly reports.
- Yearly reports.
- Charts and summaries.

**Acceptance criteria:**
- Analytics use real records.
- Calculations are documented and tested.
- Incomplete periods are not misleading.
- User data remains isolated.

---

### Phase 12 — Personalization
**Goal:** Allow users to customize their KAYA experience.

**Features:**
- Dashboard customization.
- Reorder dashboard sections.
- Theme preferences.
- Currency preferences.
- Date and locale settings.
- Custom categories.
- Assistant preferences.
- Reset-to-default settings.

**Acceptance criteria:**
- Preferences persist.
- Defaults work.
- Account switching does not expose another user's preferences.

---

### Phase 13 — Security, Privacy & Reliability
**Goal:** Make KAYA production-ready from a security perspective.

**Features and reviews:**
- RLS audit.
- Cross-account isolation tests.
- Authentication security.
- Session management.
- Secret management.
- Safe logging.
- Data export.
- Account deletion.
- Backup and recovery plan.
- Offline behavior.
- Performance optimization.
- Dependency security review.
- Privacy review.

**Acceptance criteria:**
- All private tables have verified RLS.
- Unauthorized requests are denied.
- No private credentials are committed.
- Data export and deletion workflows are reviewed.
- Known risks are documented.

---

### Phase 14 — Production & Google Play Release
**Goal:** Prepare KAYA for official Android release.

**Features and tasks:**
- Final app ID.
- App versioning.
- Branding.
- Launcher icons.
- Splash screen.
- Android release signing.
- Production backend.
- Release build.
- Android App Bundle.
- Privacy policy.
- Google Play Data Safety disclosures.
- Store description.
- Screenshots.
- Internal testing.
- Production release checklist.

**Acceptance criteria:**
- Release build tested on real devices.
- No debug secrets.
- Signing keys safely stored.
- Store disclosures accurately reflect the app.
- Publishing requires owner approval.

---

## 4. Design Rules — Do's and Don'ts

### DO
- Use consistent design tokens.
- Maintain clear visual hierarchy.
- Use readable typography.
- Use consistent spacing.
- Use reusable components.
- Provide clear primary actions.
- Support responsive layouts.
- Maintain accessibility.
- Provide loading, empty, success, and error states.
- Confirm destructive actions.
- Preserve navigation context.
- Make the interface clean and premium.

### DON'T
- Don't use random colors.
- Don't mix inconsistent button styles.
- Don't overcrowd the dashboard.
- Don't use tiny text.
- Don't rely on color alone for status.
- Don't hide essential actions.
- Don't show fake statistics as real data.
- Don't show success before the server confirms the action.
- Don't silently discard unsaved changes.
- Don't redesign unrelated screens during a specific feature task.

### Initial KAYA Visual Direction
- **Brand:** KAYA — YOUR LIFE, CLEARER.
- **Background:** `#0D1117`
- **Surface:** `#151B23`
- **Primary:** `#6EE7B7`
- **Secondary:** `#7DD3FC`
- *Initial palette proposal. Final design tokens and accessibility contrast must be reviewed in Phase 1.*
- **Typography:** Inter or a similarly readable sans-serif font.
- **Style:** Premium, calm, minimal, modern, and practical.

---

## 5. Functional Rules — Do's and Don'ts

### DO
- Put business logic in services or domain layers.
- Keep widgets focused on presentation.
- Use one source of truth for financial formulas.
- Validate inputs on client and server.
- Use stable record identifiers.
- Handle duplicate submissions.
- Provide retry for recoverable failures.
- Use pagination for growing datasets.
- Handle asynchronous requests safely.
- Separate date-only values from timestamps.

### DON'T
- Don't duplicate calculations.
- Don't trust client-side validation alone.
- Don't assume a button click means a database write succeeded.
- Don't overwrite newer server data with stale cache.
- Don't treat failed queries as empty data.
- Don't use production mock data.
- Don't allow AI to automatically mutate financial records.
- Don't make unnecessary network requests.

---

## 6. Input Validation Standards

Every form must have appropriate validation:
- Required fields must be checked.
- Trim unnecessary whitespace.
- Enforce minimum and maximum lengths.
- Validate numeric values and ranges.
- Reject `NaN` and `infinity`.
- Reject negative values where prohibited.
- Validate date ranges.
- Validate supported units and categories.
- Validate relationships between records.
- Show understandable field-level errors.
- Validate again on the server.

### Financial Validation
- Use decimal-safe arithmetic.
- Define rounding rules once.
- Do not mix currencies without valid conversion.
- Separate actual expenses from estimated costs.
- Reject unsupported or out-of-range values.
- Never silently change an amount.

---

## 7. Security & Privacy Standards

Security must be included from the beginning, not added only before release.

### Authentication
- Use trusted authentication.
- Require authorization for private operations.
- Protect sessions.
- Clear private caches on logout.
- Prevent stale requests from exposing previous account data.

### Supabase RLS
- Enable RLS on every user-owned table.
- Use least-privilege policies.
- Verify ownership on related records.
- Test `SELECT`, `INSERT`, `UPDATE`, and `DELETE`.
- Do not trust user IDs submitted by the client.
- Test that User A cannot access User B's records.

### Secrets
**NEVER:**
- Put service-role keys in Flutter.
- Commit passwords or private API keys.
- Expose database credentials.
- Store signing keys in source control.
- Print authentication tokens in logs.

Use client-safe publishable keys only when appropriate, with correctly configured RLS. Keep server secrets in server-side secret management.

### Privacy
- Collect only necessary information.
- Explain sensitive permissions.
- Never log passwords, tokens, financial records, or private document contents.
- Do not send sensitive information to AI without appropriate consent.
- Provide understandable export and account deletion options.
- Keep private file storage private.

### Secure Failure Behavior
- Fail closed if authorization cannot be verified.
- Never disable RLS to bypass an error.
- Never show another user's cached information.
- Never expose raw SQL or stack traces.
- Confirm destructive operations.

---

## 8. Testing & Validation Standards

Each feature must receive appropriate testing.

| Test type | Purpose |
| :--- | :--- |
| **Unit tests** | Calculations, dates, validation, business rules |
| **Widget tests** | Forms, states, navigation, UI behavior |
| **Service tests** | Data mapping, network errors, retries |
| **Integration tests** | End-to-end user workflows |
| **Security tests** | Authorization and account isolation |
| **Manual QA** | Real-device and browser behavior |

### Minimum Feature QA Checklist
- [ ] Valid input works.
- [ ] Missing required input is rejected.
- [ ] Invalid formats are rejected.
- [ ] Boundary values are tested.
- [ ] Loading state works.
- [ ] Empty state works.
- [ ] Error state works.
- [ ] Retry works.
- [ ] Duplicate submissions are handled.
- [ ] Account isolation is verified.
- [ ] Logout clears old data.
- [ ] Small and large layouts are tested.
- [ ] Automated tests pass.

### Flutter Validation Commands
```bash
dart format .
flutter analyze
flutter test
```
*Never remove or weaken failing tests just to achieve a green result.*

---

## 9. Recommended Project Architecture

```text
KAYA/
│
├── README.md
├── CHANGELOG.md
├── pubspec.yaml
│
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   ├── router/
│   │   └── theme/
│   │
│   ├── core/
│   │   ├── config/
│   │   ├── errors/
│   │   ├── validation/
│   │   ├── utils/
│   │   └── widgets/
│   │
│   ├── features/
│   │   ├── auth/
│   │   ├── today/
│   │   ├── tasks/
│   │   ├── money/
│   │   ├── bills/
│   │   ├── reminders/
│   │   ├── life_vault/
│   │   ├── routines/
│   │   ├── checklists/
│   │   ├── shopping/
│   │   ├── assistant/
│   │   ├── analytics/
│   │   └── settings/
│   │
│   └── main.dart
│
├── test/
│   ├── core/
│   └── features/
│
└── integration_test/
```
*Do not create unnecessary empty folders. Build architecture according to actual needs.*

---

## 10. Antigravity Coding Agent Rules

### Before Editing
1. Read `README.md`.
2. Inspect the existing project.
3. Identify related files.
4. Understand the existing implementation.
5. Identify possible database and security implications.
6. Present a plan before broad changes.

### While Editing
- Work only on the requested phase.
- Preserve working features.
- Avoid unrelated refactoring.
- Do not invent database schemas.
- Do not disable security controls.
- Do not delete data without approval.
- Explain dependencies before adding them.
- Do not change environment configuration silently.
- Stop if required permissions or credentials are missing.

### After Editing
Antigravity must report:
1. Summary of changes.
2. Files created.
3. Files modified.
4. Files deleted, if any.
5. Database changes.
6. Security considerations.
7. Tests executed.
8. Tests passed or failed.
9. Known limitations.
10. Manual QA instructions.

*Never claim a test passed if it was not actually executed.*

---

## 11. Git, Database & Release Safety

### Git Rules
- Initialize Git deliberately.
- Keep coherent development milestones.
- Review diffs before committing.
- Never force-push without approval.
- Never commit secrets or personal data.
- Avoid destructive Git commands.

### Database Rules
- Inspect schema before migrations.
- Use versioned migrations.
- Test migrations in development first.
- Never reset production data to fix a development issue.
- Review RLS whenever tables or relationships change.
- Document recovery and rollback limitations.

### Release Rules
- Separate development and production.
- Secure signing keys.
- Review Android permissions.
- Verify privacy policy.
- Test release builds.
- Obtain approval before production deployment.

---

## 12. Definition of Done

Hindi complete ang isang phase dahil lang sinabi ng Antigravity na implemented na. Tatlong validation levels ang kailangan:

1. **Level 1 — Implementation:** Required screens, models, services, controllers, and features are implemented.
2. **Level 2 — Automated Validation:** Formatting, static analysis, unit tests, and applicable integration tests pass.
3. **Level 3 — Manual QA:** Actual user workflows are tested on intended platforms, including persistence, error handling, and security.

### Phase Statuses
- `Not Started`
- `In Progress`
- `Implemented — Awaiting Validation`
- `Validated — Awaiting Manual QA`
- `Complete`
- `Blocked`

---

## 13. Current Project Status

Completely new KAYA project.

| Phase | Status |
| :--- | :--- |
| **Phase 1** | Complete |
| **Phase 2** | Complete |
| **Phase 3** | Validated — Awaiting Manual QA |
| **Phase 4** | Validated — Awaiting Manual QA |
| **Phase 5** | Validated — Awaiting Manual QA |
| **Phase 6** | Validated — Awaiting Manual QA |
| **Phase 7** | Validated — Awaiting Manual QA |
| **Phase 8** | Validated — Awaiting Manual QA |
| **Phase 9** | Validated — Awaiting Manual QA |
| **Phase 10** | Validated — Awaiting Manual QA |
| **Phase 11** | Not Started |
| **Phase 12** | Not Started |
| **Phase 13** | Not Started |
| **Phase 14** | Not Started |

*No old source code, database schema, or credentials should be assumed to exist.*

---

## 14. First Antigravity Instruction

We are starting a completely new Flutter project named KAYA.

Read the root `README.md` before doing any work.

Follow all product vision, roadmap, design rules, functional requirements, validation standards, security requirements, and coding-agent rules.

For this first task, perform environment and workspace inspection only:
1. Confirm Flutter and Dart versions.
2. Confirm Android SDK availability.
3. Confirm Android emulator availability.
4. Confirm Git availability.
5. Inspect the workspace and verify whether it is empty.
6. Recommend the minimal Phase 1 architecture.
7. Identify missing prerequisites.

**IMPORTANT:**
- Do not implement screens yet.
- Do not configure Supabase yet.
- Do not create database tables.
- Do not install unnecessary dependencies.
- Do not overwrite or delete files.
- Do not perform destructive operations.

Report findings and wait for approval before creating the Phase 1 application.

---

## 15. Owner Decisions — Never Guess

May mga decisions na dapat manggaling sa owner bago i-implement:
- Final app name and package ID.
- Final design palette and typography.
- Supported currencies.
- Exact Safe to Spend formula.
- Recurrence behavior.
- AI data-sharing permissions.
- Notification defaults.
- Data retention and deletion.
- Production hosting and release costs.

Kapag may decision na may epekto sa money, privacy, security, data loss, o production, ipaliwanag muna ang options at maghintay ng approval.

---

**KAYA** — *Your Life, Clearer.*  
Build carefully. Validate honestly. Protect the user's data.  
*Master product blueprint • 14 development phases • Antigravity engineering standards*
