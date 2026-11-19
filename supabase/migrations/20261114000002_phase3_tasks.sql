-- =============================================================================
-- KAYA Master Blueprint — Phase 3: Task Management
-- Migration: 20261114000002_phase3_tasks.sql
-- =============================================================================
-- Security, Functional & Validation Standards (Sections 5, 6, 7):
-- 1. Separate date-only values (`due_date date`) from timestamps (`timestamptz`).
-- 2. Enforce server-side CHECK constraints matching client validation rules.
-- 3. Enable and FORCE Row Level Security (RLS) on public.tasks.
-- 4. Least-privilege policies for SELECT, INSERT, UPDATE, and DELETE bound to
--    `(select auth.uid()) = user_id`.
-- =============================================================================

begin;

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  notes text not null default '',
  priority text not null default 'medium',
  category text not null default 'personal',
  due_date date null,
  is_completed boolean not null default false,
  completed_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  -- Server-side validation constraints (Section 6)
  constraint tasks_title_length_check
    check (char_length(btrim(title)) between 1 and 140),
  constraint tasks_notes_length_check
    check (char_length(notes) <= 1000),
  constraint tasks_priority_check
    check (priority in ('low', 'medium', 'high', 'urgent')),
  constraint tasks_category_check
    check (category in ('personal', 'work', 'finance', 'health', 'home', 'errands', 'other')),
  constraint tasks_due_date_range_check
    check (due_date is null or (due_date >= date '2000-01-01' and due_date <= date '2100-12-31'))
);

comment on table public.tasks is
  'User-owned tasks with priority, category, and date-only due_date for KAYA.';

create index if not exists idx_tasks_user_status_due
  on public.tasks (user_id, is_completed, due_date);

-- Automatic trim and updated_at trigger
create or replace function public.handle_tasks_before_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.title := btrim(new.title);
  new.notes := btrim(coalesce(new.notes, ''));
  new.updated_at := timezone('utc', now());
  if new.is_completed and (tg_op = 'INSERT' or old.is_completed is distinct from true) then
    new.completed_at := coalesce(new.completed_at, timezone('utc', now()));
  elsif not new.is_completed then
    new.completed_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists set_tasks_before_write on public.tasks;
create trigger set_tasks_before_write
  before insert or update on public.tasks
  for each row
  execute function public.handle_tasks_before_write();

-- Row Level Security (RLS) — Fail-closed & Least-Privilege
alter table public.tasks enable row level security;
alter table public.tasks force row level security;

revoke all on table public.tasks from anon;
grant select, insert, update, delete on table public.tasks to authenticated;

drop policy if exists "tasks_select_own" on public.tasks;
create policy "tasks_select_own"
  on public.tasks
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "tasks_insert_own" on public.tasks;
create policy "tasks_insert_own"
  on public.tasks
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "tasks_update_own" on public.tasks;
create policy "tasks_update_own"
  on public.tasks
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "tasks_delete_own" on public.tasks;
create policy "tasks_delete_own"
  on public.tasks
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

commit;
