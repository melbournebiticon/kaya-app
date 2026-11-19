-- =============================================================================
-- KAYA Master Blueprint — Phase 9: AI Integration (Usage Limits & Cost Controls)
-- Migration: 20261114000007_phase9_ai_usage_controls.sql
-- =============================================================================
-- Security & Cost Control Standards (Section 3 Phase 9, Section 7):
-- 1. Tracks per-user daily AI requests and estimated tokens for quota enforcement.
-- 2. Never stores raw private prompts, financial records, or document contents.
-- 3. Enables and FORCES Row Level Security bound to `(select auth.uid()) = user_id`.
-- =============================================================================

begin;

create table if not exists public.ai_usage_daily (
  user_id uuid not null references auth.users (id) on delete cascade,
  usage_date date not null,
  request_count integer not null default 0,
  estimated_tokens integer not null default 0,
  updated_at timestamptz not null default timezone('utc', now()),

  primary key (user_id, usage_date),

  constraint ai_usage_daily_request_count_check
    check (request_count >= 0 and request_count <= 1000),
  constraint ai_usage_daily_estimated_tokens_check
    check (estimated_tokens >= 0 and estimated_tokens <= 5000000)
);

comment on table public.ai_usage_daily is
  'Per-user daily AI request and token counters for Phase 9 usage limits and cost controls.';

alter table public.ai_usage_daily enable row level security;
alter table public.ai_usage_daily force row level security;

revoke all on table public.ai_usage_daily from anon;
grant select, insert, update on table public.ai_usage_daily to authenticated;

drop policy if exists "ai_usage_daily_select_own" on public.ai_usage_daily;
create policy "ai_usage_daily_select_own"
  on public.ai_usage_daily
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "ai_usage_daily_insert_own" on public.ai_usage_daily;
create policy "ai_usage_daily_insert_own"
  on public.ai_usage_daily
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "ai_usage_daily_update_own" on public.ai_usage_daily;
create policy "ai_usage_daily_update_own"
  on public.ai_usage_daily
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

commit;
