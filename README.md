# GitExplorer

A production-grade Flutter app for searching GitHub repositories, code, users, and issues — with real local SQLite history, bookmarks, repo health scoring, AI summaries, and notifications. **No mocked data anywhere.**

## Architecture: universal, no per-user API keys

The app talks to **your own backend proxy** (in the sibling `gitexplorer-backend` folder), which holds the real GitHub token and Groq key server-side. Every user of the app shares that one backend — nobody needs to add their own keys. See `gitexplorer-backend/README.md` for deployment (5 minutes, free tier on Render or Railway).

**You must do this before the app will work at all:**
1. Deploy `gitexplorer-backend` (steps in its README).
2. Open `lib/core/constants/api_constants.dart` and replace `backendBaseUrl` with your real deployed URL.
3. Then proceed with the Flutter setup below.

## Required first step: generate native project files

This project currently ships `lib/`, `pubspec.yaml`, and supporting assets — the actual Android/iOS native project folders (`android/`, `ios/`) are **not included** because they contain machine-generated files (especially iOS's `.xcodeproj`) that are unsafe to hand-write and must match your exact Flutter SDK version. Generate them yourself, once, with:

```bash
flutter create . --org com.yourcompany --project-name gitexplorer
```

Run this **inside the extracted project folder** (where `pubspec.yaml` already lives). It generates `android/`, `ios/`, `.gitignore`, `analysis_options.yaml`, `test/`, etc. around your existing `lib/` and `pubspec.yaml` without overwriting them (Flutter merges, it won't clobber your code).

Then apply these two manual edits:

**`android/app/src/main/AndroidManifest.xml`** — inside `<manifest>`, above `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

**`android/app/build.gradle`** — set `minSdkVersion 21` or higher (required by several packages here) and `applicationId` to your real package name.

iOS needs no extra `Info.plist` edits — notification permission is requested at runtime by code already in `main.dart`.

## Full setup, in order

```bash
flutter create . --org com.yourcompany --project-name gitexplorer   # generates android/, ios/
flutter pub get
flutter pub run flutter_launcher_icons                              # generates real app icons from assets/icons
dart run flutter_native_splash:create                                # generates the native splash screen
flutter run
```

Replace `assets/icons/app_icon.png`, `assets/icons/app_icon_fg.png`, and `assets/images/splash_logo.png` with your real branding first — the ones included are simple placeholders.

## Design notes

- Page transitions: slide-up+fade on Android, native Cupertino on iOS
- Hero shared-element transition on repo avatars between list and detail
- Staggered fade-in on search results and dashboard rows
- Tap-scale micro-interaction on every repo card
- Language-colored accent strip on repo cards, gradient AI-summary card, animated backend-status dot in Settings

## Architecture

```
lib/
  core/
    constants/         API endpoints, backend URL
    network/            dio client — talks to YOUR backend proxy, not GitHub directly
    notifications/       local notification service + background task manager
    theme/               Material3 + Cupertino-adaptive theming, custom transitions
    utils/               formatters
  data/
    models/              GhRepo, GhUser, GhCodeResult, GhIssue, HistoryEntry
    local/                sqflite DatabaseHelper, tracked-repos table, manifest parser
    remote/               GitHubApiService, GroqApiService — both call the backend proxy
  providers/              Riverpod providers (search, history, bookmarks, dashboard, phase2, notifications)
  features/                all screens (splash, dashboard, search, repo/user detail, compare, triage,
                            history, bookmarks, tracked repos, settings)
  widgets/                 shared RepoCard, staggered animation wrapper, shimmer/empty/error states

gitexplorer-backend/       separate Node/Express proxy — deploy this first (see its own README)
```

## What's real vs. known simplification

- **Trending repos**: GitHub's REST API has no official "trending" endpoint, so this is built from the real Search API (`created:>=date sort:stars`) — genuinely live data, just not GitHub's own unofficial trending page.
- **Repo Health Score**: computed client-side from real API fields (last push date, stars, issue ratio, license, archive status) — not an official GitHub metric.
- **Background notification checks**: reliable on Android via Workmanager, best-effort/OS-throttled on iOS. Manual "Check now" always works on both.
- Everything else (search, README, languages, contributors, releases, user profiles, history, bookmarks, AI summaries, compare mode, star history, risk checker, security advisories, triage view) hits the real GitHub REST API, real Groq API, or real local SQLite through the backend proxy or directly.
# GitPulese
