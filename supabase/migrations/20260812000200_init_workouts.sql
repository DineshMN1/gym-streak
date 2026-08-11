-- workouts: at most one logged workout per user per calendar day.
-- Column names mirror WorkoutLog.toMap() in lib/models/workout_log.dart.

create table if not exists public.workouts (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users (id) on delete cascade,
  date         date        not null,
  workout_type text        not null,
  completed_at timestamptz not null default now(),
  -- REQUIRED by WorkoutRepository.logWorkout()'s onConflict: 'user_id,date'.
  -- Without it every upsert fails with 42P10.
  constraint workouts_user_id_date_key unique (user_id, date)
);

create index if not exists workouts_user_id_date_idx
  on public.workouts (user_id, date desc);

alter table public.workouts enable row level security;

drop policy if exists "Owners can read their workouts" on public.workouts;
create policy "Owners can read their workouts"
  on public.workouts for select
  using (auth.uid() = user_id);

drop policy if exists "Owners can insert their workouts" on public.workouts;
create policy "Owners can insert their workouts"
  on public.workouts for insert
  with check (auth.uid() = user_id);

drop policy if exists "Owners can update their workouts" on public.workouts;
create policy "Owners can update their workouts"
  on public.workouts for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Owners can delete their workouts" on public.workouts;
create policy "Owners can delete their workouts"
  on public.workouts for delete
  using (auth.uid() = user_id);

-- DELETE events must carry user_id so the client-side .eq('user_id', ...)
-- stream filter matches them; the default (primary key only) does not.
alter table public.workouts replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.workouts;
exception
  when duplicate_object then null;
end $$;
