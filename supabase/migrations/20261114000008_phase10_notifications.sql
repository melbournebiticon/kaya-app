-- =============================================================================
-- KAYA Master Blueprint — Phase 10: Notifications & Automation
-- Migration: 20261114000008_phase10_notifications.sql
-- =============================================================================
-- Security & Privacy Standards (Section 7):
-- 1. Stores per-user notification toggles, lead times, and quiet hours.
-- 2. Enables and FORCES Row Level Security bound to `(select auth.uid()) = user_id`.
-- =============================================================================

begin;

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  notifications_enabled boolean not null default true,
  task_reminders_enabled boolean not null default true,
  bill_reminders_enabled boolean not null default true,
  document_alerts_enabled boolean not null default true,
  routine_reminders_enabled boolean not null default true,
  daily_reminder_hour integer not null default 9,
  daily_reminder_minute integer not null default 0,
  routine_reminder_hour integer not null default 8,
  routine_reminder_minute integer not null default 0,
  bill_lead_days integer not null default 3,
  document_lead_days integer not null default 14,
  quiet_hours_enabled boolean not null default true,
  quiet_start_hour integer not null default 22,
  quiet_start_minute integer not null default 0,
  quiet_end_hour integer not null default 7,
  quiet_end_minute integer not null default 0,
  updated_at timestamptz not null default timezone('utc', now()),

  constraint notif_daily_hour_check check (daily_reminder_hour between 0 and 23),
  constraint notif_daily_minute_check check (daily_reminder_minute between 0 and 59),
  constraint notif_routine_hour_check check (routine_reminder_hour between 0 and 23),
  constraint notif_routine_minute_check check (routine_reminder_minute between 0 and 59),
  constraint notif_bill_lead_check check (bill_lead_days between 0 and 30),
  constraint notif_doc_lead_check check (document_lead_days between 1 and 60),
  constraint notif_quiet_start_hour_check check (quiet_start_hour between 0 and 23),
  constraint notif_quiet_start_minute_check check (quiet_start_minute between 0 and 59),
  constraint notif_quiet_end_hour_check check (quiet_end_hour between 0 and 23),
  constraint notif_quiet_end_minute_check check (quiet_end_minute between 0 and 59)
);

alter table public.notification_preferences enable row level security;
alter table public.notification_preferences force row level security;

revoke all on table public.notification_preferences from anon;
grant select, insert, update, delete on table public.notification_preferences to authenticated;

drop policy if exists "notification_preferences_select_own" on public.notification_preferences;
create policy "notification_preferences_select_own"
  on public.notification_preferences
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "notification_preferences_insert_own" on public.notification_preferences;
create policy "notification_preferences_insert_own"
  on public.notification_preferences
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "notification_preferences_update_own" on public.notification_preferences;
create policy "notification_preferences_update_own"
  on public.notification_preferences
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "notification_preferences_delete_own" on public.notification_preferences;
create policy "notification_preferences_delete_own"
  on public.notification_preferences
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

commit;
