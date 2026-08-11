-- profiles: one row per authenticated user.
-- Column names mirror UserModel.toMap() in lib/models/user_model.dart.

create table if not exists public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  name              text        not null default '',
  email             text        not null default '',
  experience_level  text        not null default '',
  workout_types     text[]      not null default '{}',
  fitness_goals     text[]      not null default '{}',
  preferred_days    text[]      not null default '{}',
  workouts_per_week integer     not null default 3,
  onboarding_complete boolean   not null default false,
  created_at        timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Postgres has no CREATE POLICY IF NOT EXISTS; drop-then-create keeps this file
-- safe to re-run.
drop policy if exists "Owners can read their profile" on public.profiles;
create policy "Owners can read their profile"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "Owners can insert their profile" on public.profiles;
create policy "Owners can insert their profile"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "Owners can update their profile" on public.profiles;
create policy "Owners can update their profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- AuthRepository.userProfileStream() needs realtime on this table.
do $$
begin
  alter publication supabase_realtime add table public.profiles;
exception
  when duplicate_object then null;
end $$;
