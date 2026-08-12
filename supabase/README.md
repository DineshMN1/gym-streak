# Database schema

Two tables back the app: `profiles` (one row per user) and `workouts` (one row
per user per calendar day).

## Applying the migrations

The Supabase CLI is not required. Either path works.

### Dashboard (no tooling)

1. Open your project → **SQL Editor** → **New query**.
2. Paste the contents of `migrations/20260812000100_init_profiles.sql`, run it.
3. Paste the contents of `migrations/20260812000200_init_workouts.sql`, run it.
4. Paste the contents of `migrations/20260812000300_profile_trigger.sql`, run it.

Run them in filename order — the trigger in step 4 inserts into the table
created in step 2. All three files are idempotent; re-running them is safe.

## Auth settings

Under **Authentication → Providers → Email**, this project currently expects
**"Confirm email" to be OFF.**

With it on, `signUp()` returns a user but no session, so the app cannot sign the
user in immediately after registration. Supporting that properly needs a
"check your inbox" screen and deep-link handling for the confirmation redirect,
which the app does not have yet. Turning confirmation back on before real users
arrive is tracked as separate work.

### Supabase CLI (optional)

```bash
brew install supabase/tap/supabase
supabase link --project-ref <your-project-ref>
supabase db push
```

## Verifying

Run this in the SQL editor after applying. Every assertion must hold.

```sql
-- 1. RLS is on for both tables (expect two rows, rowsecurity = true).
select tablename, rowsecurity
from pg_tables
where schemaname = 'public' and tablename in ('profiles', 'workouts');

-- 2. Policies exist (expect 3 for profiles, 4 for workouts).
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 3. The unique constraint the upsert depends on (expect workouts_user_id_date_key).
select conname
from pg_constraint
where conrelid = 'public.workouts'::regclass and contype = 'u';

-- 4. Both tables publish realtime (expect profiles and workouts).
select tablename
from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'public';

-- 5. The profile trigger is installed (expect one row: on_auth_user_created).
select tgname
from pg_trigger
where tgrelid = 'auth.users'::regclass and not tgisinternal;

-- 6. Every auth user has a profile (expect zero rows).
select u.id, u.email
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;
```

## Notes

- `date` is a Postgres `date`, which PostgREST serialises as `"yyyy-MM-dd"` —
  matching `WorkoutLog.date`, which is a `String`, not a `DateTime`.
- **Profile rows are created by a trigger, not by the app.**
  `on_auth_user_created` fires on insert into `auth.users` and runs as
  `security definer`.

  This reverses an earlier decision. `AuthRepository.register()` used to insert
  the row from the client, which reads fine on paper but loses a race: when
  "Confirm email" is enabled, `signUp()` returns no session, `auth.uid()` is
  NULL for the next statement, and the RLS policy
  `with check (auth.uid() = id)` rejects the insert — so registration failed for
  every user. The insert policy is still needed for the backfill path, but the
  trigger is what makes profile creation reliable.
