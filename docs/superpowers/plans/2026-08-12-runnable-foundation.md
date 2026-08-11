# Runnable Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `gym_streak` actually bootable and actually testable — real Supabase credentials injected at build time, the database schema and RLS policies checked into the repo, and the streak maths extracted into a pure module with a real test suite behind it.

**Architecture:** Three independent seams, none of which change app behaviour for a correctly-configured user. (1) `SupabaseConfig` stops holding hardcoded placeholder strings and instead reads `String.fromEnvironment` values, validated by a pure function so it can be unit-tested without a build. (2) The `profiles` and `workouts` tables the code already assumes exist become versioned SQL under `supabase/migrations/`, including the unique constraint that the existing upsert silently depends on. (3) The streak calculation moves out of a private function inside a Riverpod provider into `lib/core/streak/`, where it is pure, dependency-free, and exhaustively tested — including a daylight-saving regression that the current implementation fails.

**Tech Stack:** Flutter 3.38.7 / Dart 3.10.7 (stable), Riverpod 2.6.1, supabase_flutter 2.12.0, go_router 15.x, google_fonts 6.x, intl 0.20.2, `flutter_test`. Postgres 15+ (Supabase).

## Global Constraints

- **No new dependencies.** `pubspec.yaml` is not modified by any task in this plan. Everything here is buildable with `flutter_test` and the packages already in `pubspec.lock`.
- **Riverpod 2.x API only.** The lockfile pins `riverpod 2.6.1`; `riverpod 3.4.2` exists but is *not* resolvable under the current constraints. Use `StreamProvider`, `Provider`, `overrideWith`, `AsyncValue.maybeWhen`. Do not introduce `@riverpod` codegen.
- **`flutter analyze` must report `No issues found!`** at the end of every task. That is the current baseline — do not regress it.
- **`flutter test` must pass** at the end of every task.
- **Formatting:** run `dart format` on every file you create or modify. The repo is default-formatted.
- **Lints:** `package:flutter_lints/flutter.yaml` (see `analysis_options.yaml`). Notably `avoid_print` is active — use `debugPrint` if you ever need output.
- **Never commit credentials.** `env.json` is gitignored by Task 4. Only `env.example.json`, containing obvious placeholders, is committed.
- **Dart version floor:** `sdk: ^3.10.7`. Dart 3 switch expressions and wildcard `_` parameters are available and already used in this codebase.
- **Date strings are always `yyyy-MM-dd`** — this is the format `WorkoutLog.date` carries and the format the Postgres `date` column serialises to over PostgREST.

## Baseline (verified before this plan was written)

```
$ flutter --version   → Flutter 3.38.7 • Dart 3.10.7
$ flutter analyze     → No issues found! (ran in 1.1s)
$ flutter test        → 00:04 +1: All tests passed!   (1 vacuous test, asserts nothing)
$ which supabase      → not found  (Supabase CLI is NOT installed; Task 2 works around this)
$ flutter devices     → macOS (desktop) and Chrome (web) only — no mobile
                        emulator/simulator is currently attached, which is why
                        Task 4 fixes the macOS sandbox network entitlement.
```

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `test/support/harness.dart` | Font config + `pumpAppWidget` tester extension | 1 |
| `test/support/fixtures.dart` | Deterministic `WorkoutLog` / date builders | 1 |
| `test/features/home/widgets/streak_card_test.dart` | First real widget test; regression guard across Task 5 | 1 |
| `supabase/migrations/20260812000100_init_profiles.sql` | `profiles` table, RLS, realtime | 2 |
| `supabase/migrations/20260812000200_init_workouts.sql` | `workouts` table, unique constraint, RLS, realtime | 2 |
| `supabase/README.md` | How to apply migrations without the CLI | 2 |
| `lib/supabase_config.dart` | Build-time config + pure validation | 3 |
| `test/core/supabase_config_test.dart` | Validation unit tests | 3 |
| `lib/core/widgets/config_error_screen.dart` | Legible "you forgot to configure me" screen | 4 |
| `lib/main.dart` | Fail-fast boot | 4 |
| `env.example.json`, `.gitignore`, `.vscode/launch.json`, `README.md` | Developer setup | 4 |
| `macos/Runner/*.entitlements` | Outbound network permission for the sandboxed macOS build | 4 |
| `lib/core/streak/streak_stats.dart` | Value type for streak results | 5 |
| `lib/core/streak/streak_engine.dart` | Pure streak maths (no Flutter, no Supabase) | 5 |
| `test/core/streak/streak_engine_test.dart` | Exhaustive streak tests incl. DST guard | 5 |

---

### Task 1: Widget & unit test harness

The existing `test/widget_test.dart` contains a test body that is entirely comments and asserts nothing — and its comment references Firebase, which this project does not use. Replace it with a harness that can render real app widgets against fake data.

Two facts this harness exists to encode, both verified experimentally:

1. `AppTheme.darkTheme` builds its text theme via `GoogleFonts.interTextTheme(...)`. google_fonts tries to download Inter over HTTP on first use; `flutter_test` blocks outbound HTTP. Setting `GoogleFonts.config.allowRuntimeFetching = false` makes it fall back to the default font silently.
2. Riverpod's `overrideWith` replaces a provider's body *entirely*. `workoutLogsProvider` and `todayWorkoutProvider` both read `Supabase.instance.client.auth.currentUser` in their bodies, which throws when Supabase was never initialised — but an overridden provider never runs its body, so **no Supabase initialisation is needed in widget tests.**

**Files:**
- Create: `test/support/harness.dart`
- Create: `test/support/fixtures.dart`
- Create: `test/features/home/widgets/streak_card_test.dart`
- Delete: `test/widget_test.dart`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  - `void configureTestFonts()` — call in `setUpAll`.
  - `extension PumpAppX on WidgetTester { Future<void> pumpAppWidget(Widget child, {List<Override> overrides = const []}) }`
  - `String isoDaysAgo(int days, {DateTime? from})` → `'yyyy-MM-dd'`
  - `WorkoutLog workoutLog(String isoDate, {String type = 'Strength'})`
  - `List<WorkoutLog> logsForDaysAgo(List<int> daysAgo, {DateTime? from})`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/home/widgets/streak_card_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/features/home/providers/workout_provider.dart';
import 'package:gym_streak/features/home/widgets/streak_card.dart';

import '../../../support/fixtures.dart';
import '../../../support/harness.dart';

void main() {
  setUpAll(configureTestFonts);

  testWidgets('renders current streak, best streak and total from logs',
      (tester) async {
    // Three consecutive days ending today, plus an isolated day 10 days back:
    //   current = 3, best = 3, total = 4 distinct days.
    final logs = logsForDaysAgo([0, 1, 2, 10]);

    await tester.pumpAppWidget(
      const StreakCard(),
      overrides: [
        workoutLogsProvider.overrideWith((ref) => Stream.value(logs)),
      ],
    );

    expect(find.text('Best Streak'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('day streak'), findsOneWidget);
    // '3' appears twice: the big current-streak number and the best-streak stat.
    expect(find.text('3'), findsNWidgets(2));
    // '4' appears once: the total stat.
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('renders zeros when there are no logs', (tester) async {
    await tester.pumpAppWidget(
      const StreakCard(),
      overrides: [
        workoutLogsProvider.overrideWith((ref) => Stream.value([])),
      ],
    );

    expect(find.text('0'), findsNWidgets(3));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/home/widgets/streak_card_test.dart`

Expected: FAIL — the support files do not exist yet:
`Error: Error when reading 'test/support/fixtures.dart': No such file or directory`
(and the same for `harness.dart`).

- [ ] **Step 3: Write the harness**

Create `test/support/harness.dart`. Note that `harness.dart` and `fixtures.dart`
do not match the `*_test.dart` glob, so the runner will not try to execute them
as test files.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gym_streak/core/theme/app_theme.dart';

/// Call once per test file, from `setUpAll`.
///
/// [AppTheme.darkTheme] builds its text theme with google_fonts, which fetches
/// Inter over HTTP on first use. `flutter_test` blocks outbound HTTP, so
/// leaving runtime fetching enabled produces noise (and, on some platforms,
/// failures). Disabling it makes google_fonts fall back to the default font.
void configureTestFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

extension PumpAppX on WidgetTester {
  /// Pumps [child] inside the real [AppTheme.darkTheme] and a [ProviderScope].
  ///
  /// Supply fake data through [overrides]. Overriding a provider replaces its
  /// body outright, so widgets under test never reach `Supabase.instance` and
  /// no Supabase initialisation is required.
  Future<void> pumpAppWidget(
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: Scaffold(body: child),
        ),
      ),
    );
    // Lets synchronous stream overrides (Stream.value) deliver their first event.
    await pump();
  }
}
```

- [ ] **Step 4: Write the fixtures**

Create `test/support/fixtures.dart`:

```dart
import 'package:gym_streak/models/workout_log.dart';
import 'package:intl/intl.dart';

final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

/// The calendar date [days] before today, as `yyyy-MM-dd`.
///
/// Arithmetic runs in UTC on purpose. Subtracting a `Duration(days: 1)` from a
/// *local* DateTime lands on the same calendar date across a daylight-saving
/// spring-forward, which would make fixtures silently wrong twice a year.
String isoDaysAgo(int days, {DateTime? from}) {
  final now = from ?? DateTime.now();
  final base = DateTime.utc(now.year, now.month, now.day)
      .subtract(Duration(days: days));
  return _isoDate.format(base);
}

WorkoutLog workoutLog(String isoDate, {String type = 'Strength'}) {
  return WorkoutLog(
    date: isoDate,
    workoutType: type,
    completedAt: DateTime.parse('${isoDate}T12:00:00Z'),
  );
}

/// One log per entry in [daysAgo], e.g. `[0, 1, 2]` = today and the two days before.
List<WorkoutLog> logsForDaysAgo(List<int> daysAgo, {DateTime? from}) {
  return daysAgo.map((d) => workoutLog(isoDaysAgo(d, from: from))).toList();
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/home/widgets/streak_card_test.dart`

Expected: PASS — `All tests passed!` (2 tests).

If instead you see a stack trace mentioning `Bad state: Supabase must be
initialized`, an override is missing: some provider in the widget tree is still
running its real body.

- [ ] **Step 6: Delete the stale placeholder test and run the whole suite**

```bash
git rm test/widget_test.dart
flutter test
```

Expected: PASS — `All tests passed!` (2 tests). The removed file's only test body
was comments, asserted nothing, and referenced Firebase, which this project does
not use; it has no replacement value.

- [ ] **Step 7: Verify the analyzer is clean**

Run: `dart format test/ && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add test/support/harness.dart test/support/fixtures.dart \
        test/features/home/widgets/streak_card_test.dart
git commit -m "test: add widget test harness and replace placeholder smoke test"
```

(`git rm` in Step 6 already staged the deletion.)

---

### Task 2: Database schema and RLS migrations

The app reads and writes `public.profiles` and `public.workouts`, but no schema exists in the repo. Two details are load-bearing and easy to get wrong:

- `WorkoutRepository.logWorkout` calls `.upsert(..., onConflict: 'user_id,date')`. **Without a unique constraint on `(user_id, date)` Postgres rejects this with `42P10: there is no unique or exclusion constraint matching the ON CONFLICT specification`.** Logging a workout would fail for every user.
- `WorkoutRepository.workoutLogsStream` / `todayWorkoutStream` / `AuthRepository.userProfileStream` use `.stream(primaryKey: ['id'])`. Realtime only emits for tables in the `supabase_realtime` publication. `workouts` additionally needs `replica identity full`, otherwise DELETE events carry only the primary key and the client-side `user_id` filter cannot match them — so `removeWorkout` would not update the UI live.

The Supabase CLI is **not installed** on this machine. Files are named to the CLI's `<timestamp>_<name>.sql` convention so `supabase db push` works later, but the documented path is the dashboard SQL editor. Every statement is written to be safely re-runnable.

**Files:**
- Create: `supabase/migrations/20260812000100_init_profiles.sql`
- Create: `supabase/migrations/20260812000200_init_workouts.sql`
- Create: `supabase/README.md`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: the `public.profiles` and `public.workouts` relations whose column names match `UserModel.toMap()` / `WorkoutLog.toMap()` exactly. `supabase/README.md` is linked from the root `README.md` in Task 4.

- [ ] **Step 1: Write the profiles migration**

Create `supabase/migrations/20260812000100_init_profiles.sql`:

```sql
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
```

- [ ] **Step 2: Write the workouts migration**

Create `supabase/migrations/20260812000200_init_workouts.sql`:

```sql
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
```

- [ ] **Step 3: Write the migration README**

Create `supabase/README.md`:

````markdown
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
````

- [ ] **Step 4: Apply and verify against a real project**

Apply both files via the dashboard SQL editor, then run the four verification
queries from `supabase/README.md`.

Expected:
1. Two rows, both `rowsecurity = t`.
2. Seven policy rows total — 3 on `profiles`, 4 on `workouts`.
3. `workouts_user_id_date_key`.
4. `profiles` and `workouts`.

If you have no project yet, create a free one at <https://supabase.com/dashboard>; you need its URL and anon key for Task 4 regardless.

- [ ] **Step 5: Commit**

```bash
git add supabase/
git commit -m "feat(db): add versioned schema and RLS policies for profiles and workouts"
```

---

### Task 3: Build-time Supabase configuration

`lib/supabase_config.dart` currently ships the literal strings `'your Supabase URL'` and `'your Supabase anon key'`. The app compiles, boots, and then fails at runtime in a confusing way. Replace them with `String.fromEnvironment` reads plus a **pure** validator, so the rules are unit-testable without performing a build.

The validator is a static method taking `url` and `anonKey` as parameters rather than reading the compile-time constants directly — that is what makes it testable, since `String.fromEnvironment` is fixed at compile time and cannot be varied per test case.

These behaviours were verified against the real `Uri.tryParse`:

| Input | `Uri.tryParse` result | Verdict |
|---|---|---|
| `https://abcd.supabase.co` | `isAbsolute=true, scheme=https, host=abcd.supabase.co` | ok |
| `your Supabase URL` | non-null but `isAbsolute=false` | malformedUrl |
| `abcd.supabase.co` | `isAbsolute=false` | malformedUrl |
| `http://abcd.supabase.co` | `scheme=http` | malformedUrl |
| `https://` | `isAbsolute=true` but `host=''` | malformedUrl |

Note `Uri.tryParse` returns non-null for the old placeholder, so an `isAbsolute`/`scheme`/`host` check is required — a null check alone would let it through.

**Files:**
- Modify: `lib/supabase_config.dart` (full rewrite, currently 10 lines)
- Create: `test/core/supabase_config_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `enum ConfigStatus { ok, missingUrl, missingAnonKey, malformedUrl }` with `String get message`
  - `SupabaseConfig.url` / `SupabaseConfig.anonKey` — `String`
  - `SupabaseConfig.status` — `ConfigStatus`
  - `SupabaseConfig.isConfigured` — `bool`
  - `SupabaseConfig.validate({required String url, required String anonKey})` — `ConfigStatus`
  - `SupabaseConfig.runCommand` — `String`, the command to show the user
  Task 4 consumes `status`, `ConfigStatus`, `message`, and `runCommand`.

- [ ] **Step 1: Write the failing test**

Create `test/core/supabase_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/supabase_config.dart';

void main() {
  group('SupabaseConfig.validate', () {
    const goodUrl = 'https://abcdefghijkl.supabase.co';
    const goodKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake.key';

    test('accepts a well-formed https project URL and key', () {
      expect(
        SupabaseConfig.validate(url: goodUrl, anonKey: goodKey),
        ConfigStatus.ok,
      );
    });

    test('reports a missing URL', () {
      expect(
        SupabaseConfig.validate(url: '', anonKey: goodKey),
        ConfigStatus.missingUrl,
      );
    });

    test('treats a whitespace-only URL as missing', () {
      expect(
        SupabaseConfig.validate(url: '   ', anonKey: goodKey),
        ConfigStatus.missingUrl,
      );
    });

    test('reports a missing anon key', () {
      expect(
        SupabaseConfig.validate(url: goodUrl, anonKey: ''),
        ConfigStatus.missingAnonKey,
      );
    });

    test('treats a whitespace-only anon key as missing', () {
      expect(
        SupabaseConfig.validate(url: goodUrl, anonKey: '  '),
        ConfigStatus.missingAnonKey,
      );
    });

    test('rejects the historical hardcoded placeholder', () {
      expect(
        SupabaseConfig.validate(
          url: 'your Supabase URL',
          anonKey: 'your Supabase anon key',
        ),
        ConfigStatus.malformedUrl,
      );
    });

    test('rejects a scheme-less host', () {
      expect(
        SupabaseConfig.validate(url: 'abcd.supabase.co', anonKey: goodKey),
        ConfigStatus.malformedUrl,
      );
    });

    test('rejects plain http', () {
      expect(
        SupabaseConfig.validate(
          url: 'http://abcd.supabase.co',
          anonKey: goodKey,
        ),
        ConfigStatus.malformedUrl,
      );
    });

    test('rejects an https URL with no host', () {
      expect(
        SupabaseConfig.validate(url: 'https://', anonKey: goodKey),
        ConfigStatus.malformedUrl,
      );
    });

    test('tolerates surrounding whitespace on otherwise valid values', () {
      expect(
        SupabaseConfig.validate(url: '  $goodUrl  ', anonKey: '  $goodKey  '),
        ConfigStatus.ok,
      );
    });
  });

  group('ConfigStatus.message', () {
    test('every status has a non-empty message', () {
      for (final status in ConfigStatus.values) {
        expect(status.message, isNotEmpty, reason: 'missing message for $status');
      }
    });
  });

  group('SupabaseConfig defaults', () {
    test('an unconfigured build is not configured', () {
      // `flutter test` runs with no --dart-define values, so the compile-time
      // constants are empty and the app must refuse to boot.
      expect(SupabaseConfig.isConfigured, isFalse);
      expect(SupabaseConfig.status, ConfigStatus.missingUrl);
    });

    test('exposes the command that fixes an unconfigured build', () {
      expect(SupabaseConfig.runCommand, contains('--dart-define-from-file'));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/supabase_config_test.dart`

Expected: FAIL with compile errors — `Error: Undefined name 'ConfigStatus'` and
`Error: Member not found: 'SupabaseConfig.validate'`.

- [ ] **Step 3: Write the implementation**

Replace the entire contents of `lib/supabase_config.dart`:

```dart
/// Supabase credentials, supplied at build time.
///
/// Nothing is hardcoded. Values arrive through `--dart-define-from-file=env.json`
/// (see `env.example.json`) or individual `--dart-define` flags, so a build made
/// without them produces an app that refuses to boot rather than one that points
/// at a placeholder URL and fails later with an opaque network error.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The command a developer should run to fix an unconfigured build.
  static const String runCommand =
      'flutter run --dart-define-from-file=env.json';

  static ConfigStatus get status => validate(url: url, anonKey: anonKey);

  static bool get isConfigured => status == ConfigStatus.ok;

  /// Pure validation, parameterised so it can be exercised in tests.
  ///
  /// [String.fromEnvironment] is fixed at compile time, so the constants above
  /// cannot be varied per test case — the rules live here instead.
  static ConfigStatus validate({
    required String url,
    required String anonKey,
  }) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return ConfigStatus.missingUrl;
    if (anonKey.trim().isEmpty) return ConfigStatus.missingAnonKey;

    // `Uri.tryParse` returns non-null for junk like 'your Supabase URL', so the
    // shape has to be checked explicitly rather than relying on a null result.
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      return ConfigStatus.malformedUrl;
    }

    return ConfigStatus.ok;
  }
}

/// Why the app can or cannot talk to Supabase.
enum ConfigStatus {
  ok,
  missingUrl,
  missingAnonKey,
  malformedUrl;

  String get message => switch (this) {
        ConfigStatus.ok => 'Supabase configuration is valid.',
        ConfigStatus.missingUrl =>
          'SUPABASE_URL was not provided at build time.',
        ConfigStatus.missingAnonKey =>
          'SUPABASE_ANON_KEY was not provided at build time.',
        ConfigStatus.malformedUrl =>
          'SUPABASE_URL is not a valid https:// project URL.',
      };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/supabase_config_test.dart`
Expected: PASS — `All tests passed!` (13 tests)

- [ ] **Step 5: Confirm nothing else broke**

Run: `dart format lib/supabase_config.dart test/core/ && flutter analyze && flutter test`

Expected: `No issues found!` then `All tests passed!`.

`lib/main.dart` still references `SupabaseConfig.url` and `SupabaseConfig.anonKey`, which both still exist — it compiles unchanged. Task 4 rewires it.

- [ ] **Step 6: Commit**

```bash
git add lib/supabase_config.dart test/core/supabase_config_test.dart
git commit -m "feat(config): read Supabase credentials from --dart-define with validation"
```

---

### Task 4: Fail-fast boot and developer setup

Wire the validated config into startup. An unconfigured build now shows an explanatory screen instead of initialising Supabase against nonsense.

**Files:**
- Create: `lib/core/widgets/config_error_screen.dart`
- Modify: `lib/main.dart` (full rewrite, currently 32 lines)
- Create: `env.example.json`
- Create: `.vscode/launch.json`
- Modify: `.gitignore` (append)
- Modify: `macos/Runner/DebugProfile.entitlements` (add network client key)
- Modify: `macos/Runner/Release.entitlements` (add network client key)
- Modify: `README.md` (full rewrite — currently unmodified Flutter boilerplate)
- Create: `test/core/widgets/config_error_screen_test.dart`

**Interfaces:**
- Consumes: `ConfigStatus`, `ConfigStatus.message`, `SupabaseConfig.status`, `SupabaseConfig.runCommand` (Task 3); `configureTestFonts`, `pumpAppWidget` (Task 1).
- Produces: `ConfigErrorApp({required ConfigStatus status})` and `ConfigErrorScreen({required ConfigStatus status})`. Two widgets, not one: `ConfigErrorApp` owns the `MaterialApp` for `runApp`, while `ConfigErrorScreen` is the bare content so a widget test can pump it inside the harness without nesting `MaterialApp`s.

- [ ] **Step 1: Write the failing widget test**

Create `test/core/widgets/config_error_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/widgets/config_error_screen.dart';
import 'package:gym_streak/supabase_config.dart';

import '../../support/harness.dart';

void main() {
  setUpAll(configureTestFonts);

  testWidgets('explains a missing URL and shows the fix', (tester) async {
    await tester.pumpAppWidget(
      const ConfigErrorScreen(status: ConfigStatus.missingUrl),
    );

    expect(find.text('Configuration required'), findsOneWidget);
    expect(find.text(ConfigStatus.missingUrl.message), findsOneWidget);
    expect(find.text(SupabaseConfig.runCommand), findsOneWidget);
  });

  testWidgets('explains a malformed URL', (tester) async {
    await tester.pumpAppWidget(
      const ConfigErrorScreen(status: ConfigStatus.malformedUrl),
    );

    expect(find.text(ConfigStatus.malformedUrl.message), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/widgets/config_error_screen_test.dart`

Expected: FAIL with
`Error: Error when reading 'lib/core/widgets/config_error_screen.dart': No such file or directory`.

- [ ] **Step 3: Write the config error screen**

Create `lib/core/widgets/config_error_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:gym_streak/core/theme/app_theme.dart';
import 'package:gym_streak/supabase_config.dart';

/// Standalone app shown when the build carries no usable Supabase credentials.
///
/// Owns its own [MaterialApp] because it is handed straight to `runApp` before
/// the real app (and its router and ProviderScope) is ever constructed.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.status});

  final ConfigStatus status;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Streak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(body: ConfigErrorScreen(status: status)),
    );
  }
}

/// The content of [ConfigErrorApp], separated so it can be widget-tested
/// inside the shared harness without nesting two [MaterialApp]s.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key, required this.status});

  final ConfigStatus status;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Configuration required',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                status.message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Copy env.example.json to env.json, fill in your project '
                      'URL and anon key, then run:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      SupabaseConfig.runCommand,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'See README.md for full setup instructions.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/widgets/config_error_screen_test.dart`
Expected: PASS — `All tests passed!` (2 tests)

- [ ] **Step 5: Rewire startup**

Replace the entire contents of `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_streak/app.dart';
import 'package:gym_streak/core/widgets/config_error_screen.dart';
import 'package:gym_streak/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Refuse to boot against absent or malformed credentials, and say why.
  final status = SupabaseConfig.status;
  if (status != ConfigStatus.ok) {
    runApp(ConfigErrorApp(status: status));
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: GymStreakApp()));
}
```

- [ ] **Step 6: Add the env example and gitignore the real one**

Create `env.example.json`:

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT-REF.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR-SUPABASE-ANON-KEY"
}
```

Append to `.gitignore` (the file currently ends with the `/android/app/release` line):

```gitignore

# Local Supabase credentials — never commit this file.
env.json
```

- [ ] **Step 7: Add the VS Code launch configuration**

Create `.vscode/launch.json`. Note `.gitignore` deliberately leaves `.vscode/` tracked (the ignore line is commented out), so this is committed on purpose.

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "gym_streak (dev)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define-from-file", "env.json"]
    },
    {
      "name": "gym_streak (profile)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile",
      "program": "lib/main.dart",
      "args": ["--dart-define-from-file", "env.json"]
    }
  ]
}
```

- [ ] **Step 8: Grant the macOS network entitlement**

macOS is one of only two run targets available on this machine (the other is
Chrome), and the app is sandboxed. Both entitlement files currently declare
`com.apple.security.network.server` (Debug only) but **neither declares
`com.apple.security.network.client`** — so a macOS build cannot make outbound
requests and every Supabase call fails, regardless of credentials. Without this
step, "run the app and log a workout" cannot succeed on macOS.

In `macos/Runner/DebugProfile.entitlements`, add the client key inside the
existing `<dict>`:

```xml
	<key>com.apple.security.network.client</key>
	<true/>
```

The file should end up as:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
```

And `macos/Runner/Release.entitlements`, which currently declares only the
sandbox key, becomes:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
```

Note these files are tab-indented; match the existing style.

- [ ] **Step 9: Replace the boilerplate README**

Replace the entire contents of `README.md`:

````markdown
# Gym Streak

Track gym workouts as a GitHub-style contribution heatmap. Flutter + Riverpod +
Supabase.

## Prerequisites

- Flutter 3.38.7 or newer (Dart 3.10.7+)
- A Supabase project — <https://supabase.com/dashboard>

## Setup

**1. Install dependencies**

```bash
flutter pub get
```

**2. Create the database schema**

Apply both migrations in `supabase/migrations/` to your project. See
[`supabase/README.md`](supabase/README.md) for the dashboard and CLI paths, plus
verification queries.

**3. Supply credentials**

Credentials are injected at build time; nothing is hardcoded and `env.json` is
gitignored.

```bash
cp env.example.json env.json
```

Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` from
**Project Settings → API** in the Supabase dashboard.

**4. Run**

```bash
flutter run --dart-define-from-file=env.json
```

VS Code users can instead pick the **gym_streak (dev)** launch configuration.

If credentials are missing or malformed the app boots into an explanatory
configuration screen rather than failing with a network error.

## Tests

```bash
flutter test
flutter analyze
```

Streak arithmetic is timezone-sensitive, so also run it under a
daylight-saving timezone — this guards the spring-forward regression described
in `lib/core/streak/streak_engine.dart`:

```bash
TZ=America/Los_Angeles flutter test test/core/streak/
```

## Layout

```
lib/
  core/          theme, router, constants, shared widgets, streak engine
  features/      auth, onboarding, home, profile, splash
  models/        UserModel, WorkoutLog
  shell/         bottom-nav shell
supabase/
  migrations/    versioned SQL schema + RLS policies
test/
  support/       shared test harness and fixtures
```
````

> **Note for the implementer:** the README references
> `lib/core/streak/streak_engine.dart` and `test/core/streak/`, which Task 5
> creates. If you are executing tasks strictly in order, this is the only
> forward reference in the plan and it resolves once Task 5 lands.

- [ ] **Step 10: Verify the whole suite and the analyzer**

```bash
dart format lib/ test/
flutter analyze
flutter test
```

Expected: `No issues found!` then `All tests passed!` (17 tests).

- [ ] **Step 11: Verify the failure path by hand**

Run the app with no credentials:

```bash
flutter run -d macos
```

Expected: the app opens on the **Configuration required** screen showing
"SUPABASE_URL was not provided at build time." and the
`flutter run --dart-define-from-file=env.json` command. It must *not* crash.

Then run it configured:

```bash
flutter run -d macos --dart-define-from-file=env.json
```

Expected: the splash screen animates and lands on `/welcome`.

- [ ] **Step 12: Commit**

```bash
git add lib/main.dart lib/core/widgets/config_error_screen.dart \
        test/core/widgets/config_error_screen_test.dart \
        env.example.json .vscode/launch.json .gitignore README.md \
        macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements
git commit -m "feat(config): fail fast with a legible screen when credentials are absent"
```

Confirm `env.json` is **not** in the staged set — `git status --short` must not
list it.

---

### Task 5: Pure streak engine

`_calculateStreak` currently lives as a private function inside
`lib/features/home/providers/workout_provider.dart:32-89`. It cannot be tested
without a Riverpod container, and it has two real defects:

**Defect 1 — daylight saving breaks streaks.** The function does
`dates[i - 1].difference(dates[i]).inDays == 1` on values from
`DateTime.parse('2026-03-08')`, which is a *local* DateTime. Across a
spring-forward, two consecutive calendar dates are 23 hours apart, and
`Duration(hours: 23).inDays` is `0` — so the chain breaks. Verified:

```
$ TZ=America/Los_Angeles dart run dst_probe.dart
2026-03-08 -> 2026-03-09: offsets -8:00 -> -7:00, inHours=23, inDays=0
3-day chain across spring-forward -> current streak = 2 (expected 3)
```

(The autumn fall-back is 25 hours, whose `inDays` is `1`, so only spring-forward
misbehaves.) The fix is to do all arithmetic on integer epoch-day numbers
derived through `DateTime.utc`, which has no offset transitions.

**Defect 2 — `total` counts rows, not days.** It returns `logs.length`. Once
Task 2's `unique (user_id, date)` constraint exists these coincide, but the
statistic should be defined on distinct days regardless.

The engine takes `Iterable<String>` rather than `List<WorkoutLog>` so it depends
on nothing — not Flutter, not Supabase, not the models.

**Files:**
- Create: `lib/core/streak/streak_stats.dart`
- Create: `lib/core/streak/streak_engine.dart`
- Create: `test/core/streak/streak_engine_test.dart`
- Modify: `lib/features/home/providers/workout_provider.dart` (replace `streakDataProvider`, delete `_calculateStreak`)
- Modify: `lib/features/profile/screens/profile_screen.dart` (one signature, one import)

**Interfaces:**
- Consumes: nothing from earlier tasks (pure). Task 1's `streak_card_test.dart` exercises the result through `streakDataProvider` and must keep passing unchanged — it is the regression guard for this refactor.
- Produces:
  - `class StreakStats { final int current; final int best; final int total; const StreakStats({required this.current, required this.best, required this.total}); static const StreakStats empty; }` with `==`, `hashCode`, `toString`.
  - `StreakEngine.calculate({required Iterable<String> dates, required DateTime today}) → StreakStats`
  - `StreakEngine.epochDayOf(DateTime) → int`
  - `StreakEngine.tryEpochDayOf(String) → int?`
  - `streakDataProvider` changes type from `Provider<({int current, int best, int total})>` to `Provider<StreakStats>`. Field names `current`, `best`, `total` are unchanged, so `StreakCard` needs no edit.

- [ ] **Step 1: Write the failing test**

Create `test/core/streak/streak_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_streak/core/streak/streak_engine.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';

void main() {
  // A fixed "today" keeps every case deterministic.
  final today = DateTime(2026, 8, 12);

  StreakStats calc(List<String> dates) =>
      StreakEngine.calculate(dates: dates, today: today);

  group('StreakEngine.calculate', () {
    test('returns empty for no dates', () {
      expect(calc([]), StreakStats.empty);
    });

    test('a single log today is a streak of one', () {
      expect(calc(['2026-08-12']),
          const StreakStats(current: 1, best: 1, total: 1));
    });

    test('counts an unbroken chain ending today', () {
      expect(calc(['2026-08-12', '2026-08-11', '2026-08-10']),
          const StreakStats(current: 3, best: 3, total: 3));
    });

    test('a chain ending yesterday is still current', () {
      // The day is not over yet; not logging today has not broken anything.
      expect(calc(['2026-08-11', '2026-08-10']),
          const StreakStats(current: 2, best: 2, total: 2));
    });

    test('a chain ending two days ago is broken but still the best', () {
      expect(calc(['2026-08-10', '2026-08-09']),
          const StreakStats(current: 0, best: 2, total: 2));
    });

    test('handles unsorted input', () {
      expect(calc(['2026-08-10', '2026-08-12', '2026-08-11']),
          const StreakStats(current: 3, best: 3, total: 3));
    });

    test('collapses duplicate dates', () {
      expect(calc(['2026-08-12', '2026-08-12', '2026-08-11']),
          const StreakStats(current: 2, best: 2, total: 2));
    });

    test('best is the longest run, current is only the trailing run', () {
      // A 4-day run in July, then a 2-day run ending today.
      expect(
        calc([
          '2026-07-01', '2026-07-02', '2026-07-03', '2026-07-04',
          '2026-08-11', '2026-08-12',
        ]),
        const StreakStats(current: 2, best: 4, total: 6),
      );
    });

    test('ignores future-dated rows', () {
      expect(calc(['2026-08-13', '2026-08-12', '2026-08-11']),
          const StreakStats(current: 2, best: 2, total: 2));
    });

    test('ignores unparseable rows', () {
      expect(calc(['not-a-date', 'garbage', '', '2026-08-12']),
          const StreakStats(current: 1, best: 1, total: 1));
    });

    test('accepts full timestamps as well as bare dates', () {
      expect(calc(['2026-08-12T10:30:00', '2026-08-11']),
          const StreakStats(current: 2, best: 2, total: 2));
    });

    test('survives a daylight-saving spring-forward', () {
      // REGRESSION GUARD. US spring-forward is 2026-03-08 02:00, so the
      // 08->09 gap is 23 local hours. The previous implementation used
      // local DateTime.difference().inDays, read that as 0, and reported 2.
      // Run this file under TZ=America/Los_Angeles to exercise it for real.
      final stats = StreakEngine.calculate(
        dates: ['2026-03-08', '2026-03-09', '2026-03-10'],
        today: DateTime(2026, 3, 10),
      );
      expect(stats, const StreakStats(current: 3, best: 3, total: 3));
    });

    test('survives a daylight-saving fall-back', () {
      final stats = StreakEngine.calculate(
        dates: ['2026-11-01', '2026-11-02', '2026-11-03'],
        today: DateTime(2026, 11, 3),
      );
      expect(stats, const StreakStats(current: 3, best: 3, total: 3));
    });
  });

  group('StreakEngine day arithmetic', () {
    test('consecutive dates are exactly one epoch day apart across DST', () {
      expect(
        StreakEngine.tryEpochDayOf('2026-03-09')! -
            StreakEngine.tryEpochDayOf('2026-03-08')!,
        1,
      );
    });

    test('tryEpochDayOf rejects junk', () {
      expect(StreakEngine.tryEpochDayOf(''), isNull);
      expect(StreakEngine.tryEpochDayOf('garbage'), isNull);
      expect(StreakEngine.tryEpochDayOf('not-a-date'), isNull);
    });

    test('epochDayOf uses local calendar fields, not the instant', () {
      expect(
        StreakEngine.epochDayOf(DateTime(2026, 8, 12, 23, 59)),
        StreakEngine.tryEpochDayOf('2026-08-12'),
      );
    });
  });

  group('StreakStats', () {
    test('values with the same fields are equal', () {
      expect(const StreakStats(current: 1, best: 2, total: 3),
          const StreakStats(current: 1, best: 2, total: 3));
      expect(const StreakStats(current: 1, best: 2, total: 3).hashCode,
          const StreakStats(current: 1, best: 2, total: 3).hashCode);
    });

    test('empty is all zeroes', () {
      expect(StreakStats.empty,
          const StreakStats(current: 0, best: 0, total: 0));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/streak/streak_engine_test.dart`

Expected: FAIL with
`Error: Error when reading 'lib/core/streak/streak_engine.dart': No such file or directory`.

- [ ] **Step 3: Write the value type**

Create `lib/core/streak/streak_stats.dart`:

```dart
/// The three numbers the UI shows for a user's workout history.
///
/// Deliberately free of any Flutter or Supabase import so the streak maths can
/// be tested as plain Dart.
class StreakStats {
  const StreakStats({
    required this.current,
    required this.best,
    required this.total,
  });

  /// Length of the run of consecutive days ending today or yesterday.
  final int current;

  /// Longest run of consecutive days ever recorded.
  final int best;

  /// Number of distinct days with at least one workout.
  final int total;

  static const StreakStats empty = StreakStats(current: 0, best: 0, total: 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakStats &&
          other.current == current &&
          other.best == best &&
          other.total == total;

  @override
  int get hashCode => Object.hash(current, best, total);

  @override
  String toString() =>
      'StreakStats(current: $current, best: $best, total: $total)';
}
```

- [ ] **Step 4: Write the engine**

Create `lib/core/streak/streak_engine.dart`:

```dart
import 'package:gym_streak/core/streak/streak_stats.dart';

/// Streak arithmetic over `yyyy-MM-dd` calendar dates.
///
/// Every comparison runs on integer *epoch day numbers* built through
/// [DateTime.utc], never on local-time [DateTime.difference]. That is not
/// stylistic: across a daylight-saving spring-forward two consecutive local
/// calendar dates are 23 hours apart, and `Duration(hours: 23).inDays` is 0, so
/// local-time subtraction silently severs an unbroken chain once a year. UTC has
/// no offset transitions, so epoch-day subtraction is always exact.
class StreakEngine {
  StreakEngine._();

  static const int _millisPerDay = 86400000;

  /// Reduces [dates] to a [StreakStats] as of [today].
  ///
  /// Unparseable entries and entries dated after [today] are ignored; duplicate
  /// dates collapse. [today] is read for its local calendar fields only.
  static StreakStats calculate({
    required Iterable<String> dates,
    required DateTime today,
  }) {
    final todayDay = epochDayOf(today);

    final days = <int>{};
    for (final raw in dates) {
      final day = tryEpochDayOf(raw);
      if (day == null) continue;
      if (day > todayDay) continue;
      days.add(day);
    }
    if (days.isEmpty) return StreakStats.empty;

    final sorted = days.toList()..sort((a, b) => b.compareTo(a)); // newest first

    // A chain ending yesterday still counts: today is not over yet.
    var current = 0;
    if (todayDay - sorted.first <= 1) {
      current = 1;
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i - 1] - sorted[i] != 1) break;
        current++;
      }
    }

    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      run = (sorted[i - 1] - sorted[i] == 1) ? run + 1 : 1;
      if (run > best) best = run;
    }

    return StreakStats(current: current, best: best, total: sorted.length);
  }

  /// The epoch day number of [dateTime]'s *calendar date*, ignoring its time
  /// and offset.
  static int epochDayOf(DateTime dateTime) =>
      DateTime.utc(dateTime.year, dateTime.month, dateTime.day)
          .millisecondsSinceEpoch ~/
      _millisPerDay;

  /// Parses a leading `yyyy-MM-dd` out of [isoDate], or null if there isn't one.
  ///
  /// Accepts a bare date or a full timestamp; only the first 10 characters are
  /// read.
  static int? tryEpochDayOf(String isoDate) {
    final trimmed = isoDate.trim();
    if (trimmed.length < 10) return null;
    final parsed = DateTime.tryParse('${trimmed.substring(0, 10)}T00:00:00Z');
    if (parsed == null) return null;
    return parsed.millisecondsSinceEpoch ~/ _millisPerDay;
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/core/streak/streak_engine_test.dart`
Expected: PASS — `All tests passed!` (18 tests)

- [ ] **Step 6: Run the streak tests under a daylight-saving timezone**

Run: `TZ=America/Los_Angeles flutter test test/core/streak/`

Expected: PASS. This is the run that would have caught Defect 1 — the old
implementation returns `current: 2` for the spring-forward case under this
timezone. `flutter test` does honour `TZ` (verified).

- [ ] **Step 7: Rewire the provider**

In `lib/features/home/providers/workout_provider.dart`:

Add these imports alongside the existing ones:

```dart
import 'package:gym_streak/core/streak/streak_engine.dart';
import 'package:gym_streak/core/streak/streak_stats.dart';
```

Replace `streakDataProvider` (lines 22-30) and **delete the whole
`_calculateStreak` function below it** (lines 32-89, i.e. through the end of the
file), leaving:

```dart
/// Streak figures derived from the user's workout logs.
final streakDataProvider = Provider<StreakStats>((ref) {
  final logsAsync = ref.watch(workoutLogsProvider);
  return logsAsync.maybeWhen(
    data: (logs) => StreakEngine.calculate(
      dates: logs.map((log) => log.date),
      today: DateTime.now(),
    ),
    orElse: () => StreakStats.empty,
  );
});
```

The file should end there. `WorkoutLog` may now be an unused import in this
file — check, and remove it only if the analyzer flags it (`workoutLogsProvider`
and `todayWorkoutProvider` still reference the type, so it is most likely still
needed).

- [ ] **Step 8: Update the one typed consumer**

`lib/features/profile/screens/profile_screen.dart` names the old record type
explicitly in a helper signature. Add the import:

```dart
import 'package:gym_streak/core/streak/streak_stats.dart';
```

Then change:

```dart
  Widget _buildStatsGrid(
    BuildContext context,
    ({int current, int best, int total}) streak,
    UserModel user,
  ) {
```

to:

```dart
  Widget _buildStatsGrid(
    BuildContext context,
    StreakStats streak,
    UserModel user,
  ) {
```

`lib/features/home/widgets/streak_card.dart` needs **no** change — it only reads
`.current`, `.best` and `.total`, whose names are identical on `StreakStats`.

- [ ] **Step 9: Verify the full suite, including the Task 1 regression guard**

```bash
dart format lib/ test/
flutter analyze
flutter test
TZ=America/Los_Angeles flutter test
```

Expected: `No issues found!`, then `All tests passed!` (35 tests) for both test
runs.

`test/features/home/widgets/streak_card_test.dart` from Task 1 must pass
**unchanged** — it was written against the old implementation's output and
asserts the new one produces the same numbers. If it fails, the refactor changed
behaviour and that is a bug, not a test to update.

- [ ] **Step 10: Commit**

```bash
git add lib/core/streak/ test/core/streak/ \
        lib/features/home/providers/workout_provider.dart \
        lib/features/profile/screens/profile_screen.dart
git commit -m "refactor(streak): extract pure streak engine and fix DST day-gap bug"
```

---

## Verification

After all five tasks:

```bash
flutter analyze                     # No issues found!
flutter test                        # All tests passed! (35 tests)
TZ=America/Los_Angeles flutter test # All tests passed! (35 tests)
flutter run --dart-define-from-file=env.json
```

End-to-end smoke test against the real project: register a new account →
complete onboarding → log a workout on the home screen → confirm the check-in
card flips to "Workout Complete!", the streak card reads 1, and today's cell
lights up in both the weekly summary and the heatmap. That single pass exercises
the RLS insert policies on both tables, the `(user_id, date)` unique constraint,
and the realtime publication.

## Out of scope

Deliberately excluded — each is a separate plan:

- **Rest-day-aware streaks.** Onboarding collects `preferredDays` and
  `workoutsPerWeek`; nothing reads them, so a planned rest day breaks a streak.
  Task 5's engine is the right seam for that change but this plan does not make it.
- **Heatmap intensity.** `AppColors.heatmapLevel1/2/3` are defined but unused —
  `contribution_heatmap.dart` renders binary on/off with `heatmapLevel4`.
- **Onboarding redirect in the router.** `app_router.dart` redirects on auth
  state only; `splash_screen.dart` is the sole thing that routes to
  `/onboarding`, so a signed-in user with `onboardingComplete == false` who lands
  anywhere else skips it.
- **CI.** No workflow runs `flutter analyze` / `flutter test` automatically.
- **Repository-layer tests.** `WorkoutRepository` and `AuthRepository` talk
  directly to `Supabase.instance` with no injection seam, so testing them needs
  either constructor injection or a fake `SupabaseClient`. The pure-engine split
  in Task 5 is what makes that gap tolerable for now.
