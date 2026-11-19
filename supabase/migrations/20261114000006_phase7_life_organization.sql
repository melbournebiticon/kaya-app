-- =============================================================================
-- KAYA Master Blueprint — Phase 7: Life Organization
-- Migration: 20261114000006_phase7_life_organization.sql
-- =============================================================================
-- Features covered:
-- 1. Smart Checklists (`public.checklists`, `public.checklist_items`)
-- 2. Daily Routines (`public.daily_routines`, `public.routine_steps`,
--    `public.routine_step_completions`)
-- 3. Shopping Lists (`public.shopping_lists`, `public.shopping_list_items`)
--
-- Security & Financial Standards:
-- - All tables carry `user_id` ownership with ENABLE + FORCE Row Level Security.
-- - Child tables also verify parent record ownership on RLS WITH CHECK / USING.
-- - Estimated shopping prices use non-negative `bigint` minor units and remain
--   strictly isolated from `public.money_transactions` (actual expenses).
-- =============================================================================

begin;

-- =============================================================================
-- 1. Smart Checklists
-- =============================================================================

create table if not exists public.checklists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint checklists_title_length_check
    check (char_length(btrim(title)) between 1 and 120)
);

create index if not exists idx_checklists_user
  on public.checklists (user_id, created_at desc);

alter table public.checklists enable row level security;
alter table public.checklists force row level security;

revoke all on table public.checklists from anon;
grant select, insert, update, delete on table public.checklists to authenticated;

drop policy if exists "checklists_select_own" on public.checklists;
create policy "checklists_select_own" on public.checklists
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "checklists_insert_own" on public.checklists;
create policy "checklists_insert_own" on public.checklists
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "checklists_update_own" on public.checklists;
create policy "checklists_update_own" on public.checklists
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "checklists_delete_own" on public.checklists;
create policy "checklists_delete_own" on public.checklists
  for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.checklist_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  checklist_id uuid not null references public.checklists (id) on delete cascade,
  title text not null,
  is_completed boolean not null default false,
  position integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint checklist_items_title_length_check
    check (char_length(btrim(title)) between 1 and 120)
);

create index if not exists idx_checklist_items_parent
  on public.checklist_items (checklist_id, position);

alter table public.checklist_items enable row level security;
alter table public.checklist_items force row level security;

revoke all on table public.checklist_items from anon;
grant select, insert, update, delete on table public.checklist_items to authenticated;

drop policy if exists "checklist_items_select_own" on public.checklist_items;
create policy "checklist_items_select_own" on public.checklist_items
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "checklist_items_insert_own" on public.checklist_items;
create policy "checklist_items_insert_own" on public.checklist_items
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.checklists c
      where c.id = checklist_id and c.user_id = (select auth.uid())
    )
  );

drop policy if exists "checklist_items_update_own" on public.checklist_items;
create policy "checklist_items_update_own" on public.checklist_items
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "checklist_items_delete_own" on public.checklist_items;
create policy "checklist_items_delete_own" on public.checklist_items
  for delete to authenticated using ((select auth.uid()) = user_id);

-- =============================================================================
-- 2. Daily Routines & Date-Only Completion Tracking
-- =============================================================================

create table if not exists public.daily_routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  scheduled_weekdays integer[] not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint daily_routines_title_length_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint daily_routines_weekdays_non_empty_check
    check (cardinality(scheduled_weekdays) >= 1 and scheduled_weekdays <@ array[1,2,3,4,5,6,7])
);

create index if not exists idx_daily_routines_user
  on public.daily_routines (user_id, created_at desc);

alter table public.daily_routines enable row level security;
alter table public.daily_routines force row level security;

revoke all on table public.daily_routines from anon;
grant select, insert, update, delete on table public.daily_routines to authenticated;

drop policy if exists "daily_routines_select_own" on public.daily_routines;
create policy "daily_routines_select_own" on public.daily_routines
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "daily_routines_insert_own" on public.daily_routines;
create policy "daily_routines_insert_own" on public.daily_routines
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "daily_routines_update_own" on public.daily_routines;
create policy "daily_routines_update_own" on public.daily_routines
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "daily_routines_delete_own" on public.daily_routines;
create policy "daily_routines_delete_own" on public.daily_routines
  for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.routine_steps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  routine_id uuid not null references public.daily_routines (id) on delete cascade,
  title text not null,
  position integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),

  constraint routine_steps_title_length_check
    check (char_length(btrim(title)) between 1 and 120)
);

alter table public.routine_steps enable row level security;
alter table public.routine_steps force row level security;

revoke all on table public.routine_steps from anon;
grant select, insert, update, delete on table public.routine_steps to authenticated;

drop policy if exists "routine_steps_select_own" on public.routine_steps;
create policy "routine_steps_select_own" on public.routine_steps
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "routine_steps_insert_own" on public.routine_steps;
create policy "routine_steps_insert_own" on public.routine_steps
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.daily_routines r
      where r.id = routine_id and r.user_id = (select auth.uid())
    )
  );

drop policy if exists "routine_steps_update_own" on public.routine_steps;
create policy "routine_steps_update_own" on public.routine_steps
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "routine_steps_delete_own" on public.routine_steps;
create policy "routine_steps_delete_own" on public.routine_steps
  for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.routine_step_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  routine_id uuid not null references public.daily_routines (id) on delete cascade,
  step_id uuid not null references public.routine_steps (id) on delete cascade,
  completion_date date not null,
  created_at timestamptz not null default timezone('utc', now()),

  constraint routine_step_completions_date_range_check
    check (completion_date >= date '2000-01-01' and completion_date <= date '2100-12-31'),
  constraint routine_step_completions_unique
    unique (user_id, step_id, completion_date)
);

alter table public.routine_step_completions enable row level security;
alter table public.routine_step_completions force row level security;

revoke all on table public.routine_step_completions from anon;
grant select, insert, delete on table public.routine_step_completions to authenticated;

drop policy if exists "routine_step_completions_select_own" on public.routine_step_completions;
create policy "routine_step_completions_select_own" on public.routine_step_completions
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "routine_step_completions_insert_own" on public.routine_step_completions;
create policy "routine_step_completions_insert_own" on public.routine_step_completions
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.routine_steps s
      where s.id = step_id and s.routine_id = routine_step_completions.routine_id and s.user_id = (select auth.uid())
    )
  );

drop policy if exists "routine_step_completions_delete_own" on public.routine_step_completions;
create policy "routine_step_completions_delete_own" on public.routine_step_completions
  for delete to authenticated using ((select auth.uid()) = user_id);

-- =============================================================================
-- 3. Shopping Lists (Estimates Kept Separate From Actual Expenses)
-- =============================================================================

create table if not exists public.shopping_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  currency text not null default 'PHP',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint shopping_lists_title_length_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint shopping_lists_currency_check
    check (currency in ('PHP', 'USD', 'EUR', 'SGD', 'JPY', 'AUD', 'GBP', 'CAD'))
);

alter table public.shopping_lists enable row level security;
alter table public.shopping_lists force row level security;

revoke all on table public.shopping_lists from anon;
grant select, insert, update, delete on table public.shopping_lists to authenticated;

drop policy if exists "shopping_lists_select_own" on public.shopping_lists;
create policy "shopping_lists_select_own" on public.shopping_lists
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "shopping_lists_insert_own" on public.shopping_lists;
create policy "shopping_lists_insert_own" on public.shopping_lists
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "shopping_lists_update_own" on public.shopping_lists;
create policy "shopping_lists_update_own" on public.shopping_lists
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "shopping_lists_delete_own" on public.shopping_lists;
create policy "shopping_lists_delete_own" on public.shopping_lists
  for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  shopping_list_id uuid not null references public.shopping_lists (id) on delete cascade,
  name text not null,
  quantity integer not null default 1,
  unit text not null default 'pcs',
  estimated_unit_price_minor bigint not null default 0,
  is_purchased boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint shopping_list_items_name_length_check
    check (char_length(btrim(name)) between 1 and 120),
  constraint shopping_list_items_quantity_check
    check (quantity between 1 and 9999),
  constraint shopping_list_items_unit_check
    check (unit in ('pcs', 'pack', 'kg', 'g', 'liter', 'bottle', 'box')),
  constraint shopping_list_items_price_minor_check
    check (estimated_unit_price_minor >= 0 and estimated_unit_price_minor <= 99999999999)
);

alter table public.shopping_list_items enable row level security;
alter table public.shopping_list_items force row level security;

revoke all on table public.shopping_list_items from anon;
grant select, insert, update, delete on table public.shopping_list_items to authenticated;

drop policy if exists "shopping_list_items_select_own" on public.shopping_list_items;
create policy "shopping_list_items_select_own" on public.shopping_list_items
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "shopping_list_items_insert_own" on public.shopping_list_items;
create policy "shopping_list_items_insert_own" on public.shopping_list_items
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.shopping_lists l
      where l.id = shopping_list_id and l.user_id = (select auth.uid())
    )
  );

drop policy if exists "shopping_list_items_update_own" on public.shopping_list_items;
create policy "shopping_list_items_update_own" on public.shopping_list_items
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "shopping_list_items_delete_own" on public.shopping_list_items;
create policy "shopping_list_items_delete_own" on public.shopping_list_items
  for delete to authenticated using ((select auth.uid()) = user_id);

commit;