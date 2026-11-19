-- =============================================================================
-- KAYA Master Blueprint — Phase 2: Authentication & User Profiles
-- Migration: 20261114000001_phase2_auth_and_profiles.sql
-- =============================================================================
-- Security & Privacy Standards (Section 7):
-- 1. Enable and FORCE Row Level Security (RLS) on public.profiles.
-- 2. Least-privilege policies for SELECT, INSERT, UPDATE, and DELETE.
-- 3. Never trust client-submitted user IDs; bind strictly to (select auth.uid()).
-- 4. Enforce server-side input validation matching client validation rules.
-- =============================================================================

begin;

-- 1. User Profiles Table
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text not null,
  preferred_currency text not null default 'PHP',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  -- Server-side validation constraints (Section 6)
  constraint profiles_email_length_check
    check (char_length(btrim(email)) between 5 and 254),
  constraint profiles_display_name_length_check
    check (char_length(btrim(display_name)) between 2 and 60),
  constraint profiles_preferred_currency_check
    check (preferred_currency in ('PHP', 'USD', 'EUR', 'SGD', 'JPY', 'AUD', 'GBP', 'CAD'))
);

comment on table public.profiles is
  'User-owned profile records and regional currency preferences for KAYA.';

-- 2. Automatic updated_at timestamp trigger
create or replace function public.handle_profiles_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.display_name := btrim(new.display_name);
  new.email := lower(btrim(new.email));
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before insert or update on public.profiles
  for each row
  execute function public.handle_profiles_updated_at();

-- 3. Automatic profile provisioning on Supabase Auth user signup
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  initial_name text;
  initial_currency text;
begin
  initial_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
    split_part(coalesce(new.email, 'KAYA User'), '@', 1)
  );
  if char_length(initial_name) < 2 then
    initial_name := 'KAYA User';
  end if;

  initial_currency := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'preferred_currency'), ''),
    'PHP'
  );
  if initial_currency not in ('PHP', 'USD', 'EUR', 'SGD', 'JPY', 'AUD', 'GBP', 'CAD') then
    initial_currency := 'PHP';
  end if;

  insert into public.profiles (id, email, display_name, preferred_currency)
  values (new.id, lower(btrim(coalesce(new.email, ''))), left(initial_name, 60), initial_currency)
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_auth_user();

-- 4. Row Level Security (RLS) — Fail-closed & Least-Privilege
alter table public.profiles enable row level security;
alter table public.profiles force row level security;

-- Revoke anonymous access explicitly
revoke all on table public.profiles from anon;
grant select, insert, update, delete on table public.profiles to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
  on public.profiles
  for delete
  to authenticated
  using ((select auth.uid()) = id);

commit;
