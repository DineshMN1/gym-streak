# Roadmap

Written 2026-08-12, after the auth, domain and distribution work landed.

## The problem worth fixing first

Onboarding asks which days you train and how many sessions a week you want.
Those answers are stored, and the **only** thing that reads them is the profile
screen, which displays them back to you.

So a user says "Mon/Wed/Fri". Tuesday arrives, they rest exactly as planned, and
the app tells them their streak is broken.

**The app punishes people for following the plan it asked them for.** That is not
a defect in the code; it is a defect in what "streak" means here. The GitHub
contribution graph is the wrong metaphor — commits are good every day, training
every day is how you get injured.

A streak should measure *adherence to a plan*, not *daily activity*. That single
change turns a generic habit tracker into a training tracker, which is the part
nobody else does well.

It is cheap now: `StreakEngine` is pure, takes `today` as a parameter, and has
tests around it. That seam exists for exactly this.

It also revives a second dead asset — `AppColors.heatmapLevel1/2/3` are defined
and unused because the heatmap is binary. Intensity should encode progress
against the user's own weekly target.

## The second problem: users are in a basement

Gyms have concrete walls and no signal. `logWorkout` awaits a network write; if
it fails the user sees nothing and assumes it worked, until tomorrow when the
streak is gone and the app gets the blame.

Local-first is not a nice-to-have for this product. Write locally, show the
streak immediately, sync when there is signal. Every other feature sits on top
of "did my workout get recorded", and today the honest answer is "probably".

## Retention mechanics that do not exist

- **No notifications at all.** Streak products die of forgetting, not
  dissatisfaction. There is no evening reminder and no "your streak is at risk".
- **The home-screen widget is read-only.** Logging currently takes five actions:
  unlock, find app, splash, Log Workout, pick type. A tap target on the widget
  makes it one.

## Order of work

1. **Rest-day-aware streaks** — uses data already collected, fixes the core lie
2. **Offline-first logging** — the basement problem
3. **Daily reminder notification** — the churn defence
4. **Widget tap-to-log** — five actions to one
5. **Heatmap intensity** driven by the weekly target

Items 1 and 2 should land before friends get a build. A beta that breaks streaks
for resting on schedule, and silently drops workouts when signal is poor, teaches
you nothing except that people stopped opening it.

## Architecture

**Keep.** Feature-first folders, the pure `core/domain` layer, repository +
Riverpod. This is a good foundation now.

**Change, in order of value:**

- `workoutLogsStream` subscribes to every workout ever logged, unbounded, and
  re-sends the whole set on every change. At three years that is roughly a
  thousand rows over realtime per check-in, to draw a heatmap covering one year.
  Bound it to the visible window.
- Repository tests only prove construction. The injection seam exists; the next
  step is a fake HTTP layer so `42501` can be asserted to surface as
  `PermissionDenied`.
- `models/` should dissolve into feature domains — `WorkoutLog` lives far from
  everything that uses it.

## Deliberately not doing

- **Social features / leaderboards.** Solo retention is unproven; social
  multiplies a number nobody has measured yet.
- **Sets, reps and weight logging.** A different product in a crowded market
  (Strong, Hevy). The wedge here is consistency, not performance.
- **Apple Health / Google Fit.** Large surface area, no effect on retention.
- **An iOS widget**, until the Android one proves people use it.
- **Monetisation**, for at least six months.

## Known gaps carried forward

- Email confirmation is off (`supabase/README.md`); a mistyped signup address is
  unrecoverable even with password reset in place.
- `removeWorkout` exists with no caller, so a mis-tapped workout type cannot be
  corrected.
- `todayWorkoutStream` recomputes "today" per emission, but nothing invalidates
  the provider at local midnight, so a screen left open still needs a nudge.
