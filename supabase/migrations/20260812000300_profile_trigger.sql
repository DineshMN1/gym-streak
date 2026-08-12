-- Create the profile row server-side, when the auth user is created.
--
-- This replaces a client-side insert that used to run in AuthRepository.register()
-- immediately after signUp(). That approach is unreliable: when "Confirm email"
-- is enabled, signUp() returns a user but NO session, so auth.uid() is NULL for
-- the very next statement and the RLS policy
--   "Owners can insert their profile"  with check (auth.uid() = id)
-- rejects the write. Registration then fails for every user.
--
-- Running as `security definer` sidesteps RLS and the session-timing race
-- entirely: by the time this fires, auth.users already holds the row.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
-- Empty search_path is deliberate: a security definer function that resolves
-- unqualified names through the caller's search_path is hijackable. Every
-- identifier below is therefore schema-qualified.
set search_path = ''
as $$
begin
  insert into public.profiles (id, name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    coalesce(new.email, '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Postgres has no CREATE TRIGGER IF NOT EXISTS; drop-then-create keeps this file
-- safe to re-run.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Nothing should be able to call this directly; only the trigger needs it.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Backfill: any auth user created before this migration (test accounts, or an
-- account whose client-side insert was rejected) gets its missing profile row.
insert into public.profiles (id, name, email)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'name', ''),
  coalesce(u.email, '')
from auth.users u
on conflict (id) do nothing;
