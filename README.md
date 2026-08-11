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
