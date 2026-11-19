-- =============================================================================
-- KAYA Master Blueprint — Phase 5: Bills & Reminders
-- Migration: 20261114000004_phase5_bills_and_reminders.sql
-- =============================================================================
-- Security, Financial & Validation Standards (Sections 3, 5, 6, 7):
-- 1. Decimal-safe bill amounts (`amount_minor bigint > 0`) compatible with the
--    centralized Safe to Spend engine.
-- 2. Unique constraint `(user_id, recurrence_group_id, due_date)` prevents
--    duplicate recurring bill generation at the database layer.
-- 3. Separate date-only `due_date date` from UTC `timestamptz` audit fields.
-- 4. Enable and FORCE Row Level Security (RLS) on public.bills and
--    public.reminders bound to `(select auth.uid()) = user_id`.
-- =============================================================================

begin;

create table if not exists public.bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  recurrence_group_id text not null,
  title text not null,
  notes text not null default '',
  category text not null default 'utilities',
  amount_minor bigint not null,
  currency text not null default 'PHP',
  due_date date not null,
  recurrence text not null default 'one_time',
  is_paid boolean not null default false,
  paid_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint bills_title_length_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint bills_notes_length_check
    check (char_length(notes) <= 500),
  constraint bills_category_check
    check (
      category in (
        'utilities',
        'housing',
        'internet_phone',
        'insurance',
        'subscriptions',
        'credit_debt',
        'taxes_gov',
        'other'
      )
    ),
  constraint bills_amount_minor_check
    check (amount_minor > 0 and amount_minor <= 99999999999),
  constraint bills_currency_check
    check (currency in ('PHP', 'USD', 'EUR', 'SGD', 'JPY', 'AUD', 'GBP', 'CAD')),
  constraint bills_due_date_range_check
    check (due_date >= date '2000-01-01' and due_date <= date '2100-12-31'),
  constraint bills_recurrence_check
    check (recurrence in ('one_time', 'monthly', 'yearly')),
  constraint bills_recurrence_group_unique_cycle
    unique (user_id, recurrence_group_id, due_date)
);

comment on table public.bills is
  'User-owned bills with paid/unpaid state, integer minor-unit amounts, due_date, and non-duplicating recurrence.';

create index if not exists idx_bills_user_paid_due
  on public.bills (user_id, is_paid, due_date);

create or replace function public.handle_bills_before_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.title := btrim(new.title);
  new.notes := btrim(coalesce(new.notes, ''));
  new.currency := upper(btrim(new.currency));
  new.recurrence_group_id := coalesce(nullif(btrim(new.recurrence_group_id), ''), new.id::text);
  new.updated_at := timezone('utc', now());
  if new.is_paid and (tg_op = 'INSERT' or old.is_paid is distinct from true) then
    new.paid_at := coalesce(new.paid_at, timezone('utc', now()));
  elsif not new.is_paid then
    new.paid_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists set_bills_before_write on public.bills;
create trigger set_bills_before_write
  before insert or update on public.bills
  for each row
  execute function public.handle_bills_before_write();

-- Row Level Security for public.bills
alter table public.bills enable row level security;
alter table public.bills force row level security;

revoke all on table public.bills from anon;
grant select, insert, update, delete on table public.bills to authenticated;

drop policy if exists "bills_select_own" on public.bills;
create policy "bills_select_own"
  on public.bills
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "bills_insert_own" on public.bills;
create policy "bills_insert_own"
  on public.bills
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "bills_update_own" on public.bills;
create policy "bills_update_own"
  on public.bills
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "bills_delete_own" on public.bills;
create policy "bills_delete_own"
  on public.bills
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- =============================================================================
-- Reminders Table
-- =============================================================================

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  notes text not null default '',
  due_date date not null,
  is_completed boolean not null default false,
  completed_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint reminders_title_length_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint reminders_notes_length_check
    check (char_length(notes) <= 500),
  constraint reminders_due_date_range_check
    check (due_date >= date '2000-01-01' and due_date <= date '2100-12-31')
);

comment on table public.reminders is
  'User-owned date-only reminders with completion state for KAYA.';

create index if not exists idx_reminders_user_status_due
  on public.reminders (user_id, is_completed, due_date);

create or replace function public.handle_reminders_before_write()
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

drop trigger if exists set_reminders_before_write on public.reminders;
create trigger set_reminders_before_write
  before insert or update on public.reminders
  for each row
  execute function public.handle_reminders_before_write();

-- Row Level Security for public.reminders
alter table public.reminders enable row level security;
alter table public.reminders force row level security;

revoke all on table public.reminders from anon;
grant select, insert, update, delete on table public.reminders to authenticated;

drop policy if exists "reminders_select_own" on public.reminders;
create policy "reminders_select_own"
  on public.reminders
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "reminders_insert_own" on public.reminders;
create policy "reminders_insert_own"
  on public.reminders
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "reminders_update_own" on public.reminders;
create policy "reminders_update_own"
  on public.reminders
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "reminders_delete_own" on public.reminders;
create policy "reminders_delete_own"
  on public.reminders
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

commit;