# Database schema

Two tables back the app: `profiles` (one row per user) and `workouts` (one row
per user per calendar day).

## Applying the migrations

The Supabase CLI is not required. Either path works.

### Dashboard (no tooling)

1. Open your project → **SQL Editor** → **New query**.
2. Paste the contents of `migrations/20260812000100_init_profiles.sql`, run it.
3. Paste the contents of `migrations/20260812000200_init_workouts.sql`, run it.

Both files are idempotent — re-running them is safe.

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
```

## Notes

- `date` is a Postgres `date`, which PostgREST serialises as `"yyyy-MM-dd"` —
  matching `WorkoutLog.date`, which is a `String`, not a `DateTime`.
- The app creates the profile row itself in `AuthRepository.register()`, so
  there is deliberately no `on auth.users` insert trigger. The insert policy is
  what makes that write legal.
