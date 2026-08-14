# Releasing to testers

How a change gets from your editor to your friends' phones, and the gates that
stop a broken one getting there.

## The short version

```
edit → test on your own phone → branch → PR → CI green → merge → distribute
```

You are currently pushing straight to `main`, which means the first thing that
checks your work is your testers. The steps below move that check earlier.

---

## Layer 1 — your own phone, before anything else

Nothing replaces running it. Plug in the S24 and:

```bash
flutter run --dart-define-from-file=env.json
```

Hot reload with `r`, restart with `R`. This is a debug build: slower, but it
catches the obvious things in seconds rather than after a release cycle.

**Release builds behave differently.** Two real bugs in this project only ever
appeared in release: the missing `INTERNET` permission, and the adaptive icon
mask. Before distributing, always test the actual artefact:

```bash
flutter build apk --release --dart-define-from-file=env.json
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Layer 2 — the pre-push hook

`.githooks/pre-push` runs the same four gates as CI and refuses the push if any
fail. Enable it once per clone:

```bash
git config core.hooksPath .githooks
```

It checks formatting, `flutter analyze`, the test suite, and the suite again
under `TZ=America/Los_Angeles`. Takes about forty seconds.

To bypass in an emergency: `git push --no-verify`. If you find yourself doing
that regularly, the checks are wrong and should be fixed rather than skipped.

## Layer 3 — branch and pull request

Stop committing to `main`. Instead:

```bash
git checkout -b fix/whatever-it-is
# ...work...
git push -u origin fix/whatever-it-is
gh pr create --fill
```

CI runs on the pull request. Merge only when it is green. This is what gives you
a place to look at a change before it becomes the thing you ship, and it means
`main` is always releasable.

## Layer 4 — distribution

Manual on purpose: **Actions → Distribute Android → Run workflow**. Sending a
build to real people should be a decision, not a side effect of merging.

The workflow re-runs the whole suite, refuses to proceed if any secret is
missing, and verifies the APK is not debug-signed before uploading.

---

## Checklist: before the first build ever goes out

Nothing below can be done from the repository — all of it is dashboard work.

- [ ] **Keystore generated** and `android/key.properties` filled in
      (`docs/distribution.md` step 1). **Back the `.jks` up somewhere durable** —
      losing it means no tester can ever install an update.
- [ ] **Firebase project created**, Android app added with package name
      exactly `com.gymstreak.gym_streak`, App ID copied
- [ ] **Service account** created with the Firebase App Distribution Admin role,
      JSON key downloaded
- [ ] **Eight GitHub secrets** added (table in `docs/distribution.md`)
- [ ] **Tester group** named `friends` created, with their email addresses
- [ ] **`git config core.hooksPath .githooks`** run on this machine
- [ ] **Password reset tested end to end** on a real device — request the email,
      open the link on the phone, set a new password
- [ ] **Decide on email confirmation.** It is currently **off**, so anyone can
      register with an address they do not own and a typo is unrecoverable.
      Among a few trusted friends that is survivable; write down that you chose
      it rather than discovering it later.

## Checklist: every release

- [ ] Tested the **release** APK on your own phone, not just debug
- [ ] Bumped `version:` in `pubspec.yaml` — the `+N` build number must increase
      every upload or the store rejects it
- [ ] Merged to `main` through a green PR
- [ ] Ran **Distribute Android** with release notes your friends will actually
      read
- [ ] Watched the workflow finish; a failure at the signature check means the
      keystore secrets are wrong

## What your testers do

**First time:** they get an email, accept the invitation, install the Firebase
App Tester app, then install the build. Android asks them to allow installs from
unknown sources — normal for anything outside Play.

**Every update after that:** App Tester notifies them and they tap to install.
No uninstall needed, because every build is signed with the same key. That is
the entire reason the keystore matters.

**Tell them two things up front:**

- Reminders need Gym Streak set to **Unrestricted** under Settings → Apps →
  Battery, or Samsung's battery manager will silently suppress them.
- Workouts logged with no signal are queued and sync when the app next opens
  with a connection. It is not lost, even though the server has not seen it yet.

## When a tester reports something

Ask for three things: what they did, what happened, and what phone. Then
reproduce it on your own device before changing code — every bug in this project
so far has had a specific root cause, and the ones that looked like "the network
is flaky" were a missing manifest permission and a websocket race.
