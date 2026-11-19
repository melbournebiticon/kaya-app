-- =============================================================================
-- KAYA Master Blueprint — Phase 6: Life Vault
-- Migration: 20261114000005_phase6_life_vault.sql
-- =============================================================================
-- Security, Privacy & Validation Standards (Sections 3, 5, 6, 7):
-- 1. Separate date-only issue/expiration/return dates (`date`) from UTC audit
--    timestamps (`timestamptz`).
-- 2. Enforce server-side CHECK constraints (title/location length, date ranges,
--    expiration_date >= issue_date, counterparty required for loans).
-- 3. Enable and FORCE Row Level Security (RLS) on public.vault_documents and
--    public.personal_belongings bound to `(select auth.uid()) = user_id`.
-- =============================================================================

begin;

create table if not exists public.vault_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  category text not null default 'government_id',
  physical_location text not null,
  notes text not null default '',
  issue_date date null,
  expiration_date date null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint vault_documents_title_length_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint vault_documents_category_check
    check (
      category in (
        'government_id',
        'passport_visa',
        'financial_tax',
        'insurance_medical',
        'property_vehicle',
        'warranty_contract',
        'education_certificate',
        'other'
      )
    ),
  constraint vault_documents_location_length_check
    check (char_length(btrim(physical_location)) between 1 and 120),
  constraint vault_documents_notes_length_check
    check (char_length(notes) <= 500),
  constraint vault_documents_issue_date_range_check
    check (
      issue_date is null or
      (issue_date >= date '1950-01-01' and issue_date <= date '2100-12-31')
    ),
  constraint vault_documents_expiration_date_range_check
    check (
      expiration_date is null or
      (expiration_date >= date '1950-01-01' and expiration_date <= date '2100-12-31')
    ),
  constraint vault_documents_date_order_check
    check (
      issue_date is null or expiration_date is null or expiration_date >= issue_date
    )
);

comment on table public.vault_documents is
  'Private user-owned documents with physical locations, issue dates, and expiration tracking.';

create index if not exists idx_vault_documents_user_expiration
  on public.vault_documents (user_id, expiration_date);

create or replace function public.handle_vault_documents_before_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.title := btrim(new.title);
  new.physical_location := btrim(new.physical_location);
  new.notes := btrim(coalesce(new.notes, ''));
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_vault_documents_before_write on public.vault_documents;
create trigger set_vault_documents_before_write
  before insert or update on public.vault_documents
  for each row
  execute function public.handle_vault_documents_before_write();

-- Row Level Security for public.vault_documents
alter table public.vault_documents enable row level security;
alter table public.vault_documents force row level security;

revoke all on table public.vault_documents from anon;
grant select, insert, update, delete on table public.vault_documents to authenticated;

drop policy if exists "vault_documents_select_own" on public.vault_documents;
create policy "vault_documents_select_own"
  on public.vault_documents
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "vault_documents_insert_own" on public.vault_documents;
create policy "vault_documents_insert_own"
  on public.vault_documents
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "vault_documents_update_own" on public.vault_documents;
create policy "vault_documents_update_own"
  on public.vault_documents
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "vault_documents_delete_own" on public.vault_documents;
create policy "vault_documents_delete_own"
  on public.vault_documents
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- =============================================================================
-- Personal Belongings & Borrowed/Lent Items Table
-- =============================================================================

create table if not exists public.personal_belongings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  category text not null default 'electronics',
  storage_location text not null,
  notes text not null default '',
  custody_type text not null default 'owned',
  counterparty_name text not null default '',
  due_return_date date null,
  is_returned boolean not null default false,
  returned_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint personal_belongings_title_length_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint personal_belongings_category_check
    check (
      category in (
        'electronics',
        'tools_equipment',
        'books_media',
        'documents_cards',
        'apparel_accessories',
        'home_kitchen',
        'valuables',
        'other'
      )
    ),
  constraint personal_belongings_location_length_check
    check (char_length(btrim(storage_location)) between 1 and 120),
  constraint personal_belongings_notes_length_check
    check (char_length(notes) <= 500),
  constraint personal_belongings_custody_type_check
    check (custody_type in ('owned', 'lent_out', 'borrowed')),
  constraint personal_belongings_counterparty_check
    check (
      (custody_type = 'owned' and char_length(counterparty_name) <= 120)
      or
      (
        custody_type in ('lent_out', 'borrowed') and
        char_length(btrim(counterparty_name)) between 1 and 120
      )
    ),
  constraint personal_belongings_due_return_range_check
    check (
      due_return_date is null or
      (due_return_date >= date '2000-01-01' and due_return_date <= date '2100-12-31')
    )
);

comment on table public.personal_belongings is
  'User-owned personal belongings, storage locations, and borrowed/lent return tracking.';

create index if not exists idx_personal_belongings_user_custody
  on public.personal_belongings (user_id, custody_type, is_returned);

create or replace function public.handle_personal_belongings_before_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.title := btrim(new.title);
  new.storage_location := btrim(new.storage_location);
  new.notes := btrim(coalesce(new.notes, ''));
  new.counterparty_name := btrim(coalesce(new.counterparty_name, ''));
  new.updated_at := timezone('utc', now());

  if new.custody_type = 'owned' then
    new.counterparty_name := '';
    new.is_returned := false;
    new.returned_at := null;
  elsif new.is_returned and (tg_op = 'INSERT' or old.is_returned is distinct from true) then
    new.returned_at := coalesce(new.returned_at, timezone('utc', now()));
  elsif not new.is_returned then
    new.returned_at := null;
  end if;

  return new;
end;
$$;

drop trigger if exists set_personal_belongings_before_write on public.personal_belongings;
create trigger set_personal_belongings_before_write
  before insert or update on public.personal_belongings
  for each row
  execute function public.handle_personal_belongings_before_write();

-- Row Level Security for public.personal_belongings
alter table public.personal_belongings enable row level security;
alter table public.personal_belongings force row level security;

revoke all on table public.personal_belongings from anon;
grant select, insert, update, delete on table public.personal_belongings to authenticated;

drop policy if exists "personal_belongings_select_own" on public.personal_belongings;
create policy "personal_belongings_select_own"
  on public.personal_belongings
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "personal_belongings_insert_own" on public.personal_belongings;
create policy "personal_belongings_insert_own"
  on public.personal_belongings
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "personal_belongings_update_own" on public.personal_belongings;
create policy "personal_belongings_update_own"
  on public.personal_belongings
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "personal_belongings_delete_own" on public.personal_belongings;
create policy "personal_belongings_delete_own"
  on public.personal_belongings
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

commit;