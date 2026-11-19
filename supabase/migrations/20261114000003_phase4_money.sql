-- =============================================================================
-- KAYA Master Blueprint — Phase 4: Money Management
-- Migration: 20261114000003_phase4_money.sql
-- =============================================================================
-- Security, Financial & Validation Standards (Sections 3, 5, 6, 7):
-- 1. Decimal-safe storage using integer minor currency units (`amount_minor bigint`,
--    `overall_limit_minor bigint`), never floating-point money columns.
-- 2. Separate date-only `transaction_date date` from UTC `timestamptz` audit fields.
-- 3. Enforce server-side CHECK constraints matching client validation rules.
-- 4. Enable and FORCE Row Level Security (RLS) on both public.money_transactions
--    and public.monthly_budgets bound to `(select auth.uid()) = user_id`.
-- =============================================================================

begin;

create table if not exists public.money_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null,
  category text not null,
  title text not null,
  notes text not null default '',
  amount_minor bigint not null,
  currency text not null default 'PHP',
  transaction_date date not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint money_transactions_type_check
    check (type in ('income', 'expense')),
  constraint money_transactions_category_check
    check (
      (type = 'income' and category in (
        'salary', 'freelance', 'business', 'investment', 'gift', 'other_income'
      ))
      or
      (type = 'expense' and category in (
        'food', 'housing', 'utilities', 'transport', 'healthcare',
        'shopping', 'entertainment', 'education', 'savings', 'other_expense'
      ))
    ),
  constraint money_transactions_title_length_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint money_transactions_notes_length_check
    check (char_length(notes) <= 500),
  constraint money_transactions_amount_minor_check
    check (amount_minor > 0 and amount_minor <= 99999999999),
  constraint money_transactions_currency_check
    check (currency in ('PHP', 'USD', 'EUR', 'SGD', 'JPY', 'AUD', 'GBP', 'CAD')),
  constraint money_transactions_date_range_check
    check (transaction_date >= date '2000-01-01' and transaction_date <= date '2100-12-31')
);

comment on table public.money_transactions is
  'Actual user-owned income and expense transactions stored in decimal-safe minor units.';

create index if not exists idx_money_transactions_user_date
  on public.money_transactions (user_id, transaction_date desc, type);

create or replace function public.handle_money_transactions_before_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.title := btrim(new.title);
  new.notes := btrim(coalesce(new.notes, ''));
  new.currency := upper(btrim(new.currency));
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_money_transactions_before_write on public.money_transactions;
create trigger set_money_transactions_before_write
  before insert or update on public.money_transactions
  for each row
  execute function public.handle_money_transactions_before_write();

-- Row Level Security for money_transactions
alter table public.money_transactions enable row level security;
alter table public.money_transactions force row level security;

revoke all on table public.money_transactions from anon;
grant select, insert, update, delete on table public.money_transactions to authenticated;

drop policy if exists "money_transactions_select_own" on public.money_transactions;
create policy "money_transactions_select_own"
  on public.money_transactions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "money_transactions_insert_own" on public.money_transactions;
create policy "money_transactions_insert_own"
  on public.money_transactions
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "money_transactions_update_own" on public.money_transactions;
create policy "money_transactions_update_own"
  on public.money_transactions
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "money_transactions_delete_own" on public.money_transactions;
create policy "money_transactions_delete_own"
  on public.money_transactions
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- =============================================================================
-- Monthly Budgets Table
-- =============================================================================

create table if not exists public.monthly_budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  year integer not null,
  month integer not null,
  currency text not null default 'PHP',
  overall_limit_minor bigint not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint monthly_budgets_year_check
    check (year between 2000 and 2100),
  constraint monthly_budgets_month_check
    check (month between 1 and 12),
  constraint monthly_budgets_currency_check
    check (currency in ('PHP', 'USD', 'EUR', 'SGD', 'JPY', 'AUD', 'GBP', 'CAD')),
  constraint monthly_budgets_limit_minor_check
    check (overall_limit_minor > 0 and overall_limit_minor <= 99999999999),
  constraint monthly_budgets_user_period_currency_unique
    unique (user_id, year, month, currency)
);

comment on table public.monthly_budgets is
  'User-owned monthly spending limits in integer minor currency units.';

create index if not exists idx_monthly_budgets_user_period
  on public.monthly_budgets (user_id, year, month, currency);

create or replace function public.handle_monthly_budgets_before_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.currency := upper(btrim(new.currency));
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_monthly_budgets_before_write on public.monthly_budgets;
create trigger set_monthly_budgets_before_write
  before insert or update on public.monthly_budgets
  for each row
  execute function public.handle_monthly_budgets_before_write();

-- Row Level Security for monthly_budgets
alter table public.monthly_budgets enable row level security;
alter table public.monthly_budgets force row level security;

revoke all on table public.monthly_budgets from anon;
grant select, insert, update, delete on table public.monthly_budgets to authenticated;

drop policy if exists "monthly_budgets_select_own" on public.monthly_budgets;
create policy "monthly_budgets_select_own"
  on public.monthly_budgets
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "monthly_budgets_insert_own" on public.monthly_budgets;
create policy "monthly_budgets_insert_own"
  on public.monthly_budgets
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "monthly_budgets_update_own" on public.monthly_budgets;
create policy "monthly_budgets_update_own"
  on public.monthly_budgets
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "monthly_budgets_delete_own" on public.monthly_budgets;
create policy "monthly_budgets_delete_own"
  on public.monthly_budgets
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

commit;