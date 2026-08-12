# Shipping betas to testers

Android builds go out through **Firebase App Distribution**, driven by
`.github/workflows/distribute-android.yml`. CI (`ci.yml`) runs on every push and
pull request.

## Before the first build

Four one-time jobs. Nothing here can be automated from inside the repo.

### 1. Create the release keystore

```bash
keytool -genkey -v -keystore ~/gym-streak-release.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias gym-streak
```

Then copy `android/key.properties.example` to `android/key.properties` and fill
it in. That file and the `.jks` are both gitignored.

> **Back the keystore up somewhere you will still have in two years.** Android
> refuses to install an update signed with a different key. Lose this file and
> every tester has to uninstall and lose their local state — and if the app is
> on Play by then, you cannot ship an update at all.

### 2. Create the Firebase project

1. <https://console.firebase.google.com> → add a project.
2. Add an **Android** app with package name **`com.gymstreak.gym_streak`**.
   It must match exactly, or App Distribution rejects the upload.
3. Copy the **App ID** (looks like `1:123456789:android:abc123`).

You do **not** need `google-services.json`, and you do **not** need to add any
Firebase package to `pubspec.yaml`. App Distribution only ships the APK; the
Firebase SDK is for apps that actually use Firebase services.

### 3. Create a service account for CI

In the Google Cloud console for that project: **IAM → Service Accounts → Create**,
grant it the **Firebase App Distribution Admin** role, then create a JSON key and
download it.

### 4. Add the GitHub secrets

**Settings → Secrets and variables → Actions** on `DineshMN1/gym-streak`:

| Secret | Value |
|---|---|
| `SUPABASE_URL` | From Supabase → Project Settings → API |
| `SUPABASE_ANON_KEY` | Same page |
| `ANDROID_KEYSTORE_BASE64` | `base64 -i ~/gym-streak-release.jks \| pbcopy` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password from step 1 |
| `ANDROID_KEY_ALIAS` | `gym-streak` |
| `ANDROID_KEY_PASSWORD` | Key password from step 1 |
| `FIREBASE_ANDROID_APP_ID` | The App ID from step 2 |
| `FIREBASE_SERVICE_ACCOUNT` | The entire JSON file contents from step 3 |

The workflow fails with a clear message if any of these is missing, rather than
quietly shipping a broken or debug-signed build.

### 5. Add testers

Firebase console → **App Distribution → Testers & Groups**. Create a group named
`friends` (the workflow's default) and add their email addresses.

## Shipping a build

GitHub → **Actions → Distribute Android → Run workflow**. Fill in the release
notes; testers see them in the email.

It is deliberately manual. Sending a build to real people should be a decision,
not a side effect of merging. To ship on every merge instead, uncomment the
`push:` trigger at the top of the workflow.

Before shipping, bump the build number in `pubspec.yaml`:

```yaml
version: 1.0.0+2   # 1.0.0 is shown to users; +2 must increase every upload
```

## What testers do

**First time:** they get an email, accept the invitation, install the Firebase
App Tester app, then install the build. Android will ask them to allow installs
from unknown sources — that is normal for anything outside Play.

**Updates:** App Tester notifies them and they tap to install. No uninstall
needed, because every build is signed with the same key.

## Two things to settle before real testers

Both are known gaps, not surprises.

**There is no password reset.** No `resetPasswordForEmail` call exists anywhere
in `lib/`. The first tester who forgets their password is locked out and the
only fix is editing the database by hand.

**Email confirmation is off.** It was disabled deliberately so development could
proceed (see `supabase/README.md`). While it is off, anyone can register with any
address including one they do not own, and a mistyped address is unrecoverable
because of the point above. Among a few trusted friends this is survivable;
beyond that it is not. Turning it back on needs a "check your inbox" screen and
deep-link handling, neither of which exists yet.

## Why CI runs the test suite twice

`ci.yml` runs `flutter test` and then runs it again under
`TZ=America/Los_Angeles`. That second run is the point of having CI at all.

The streak engine had a bug where two calendar days either side of a
daylight-saving spring-forward are 23 hours apart, and `Duration(hours: 23)
.inDays` is `0` — so an unbroken streak silently broke, once a year. The tests
guarding that are **inert in a timezone without DST**: under UTC (the CI default)
and under IST (this machine) the old buggy implementation passes them too.

Only the `TZ=` run can fail if the bug returns. Do not remove it.
