# Builder Plaza — Flutter client

The Builder Plaza client is a responsive Flutter application for Android, iOS,
and web. It presents the Trust Gateway onboarding flow, shared role-aware home
shell, Project Cards, Growth Plaza, explainable matching, Trust Score and
evidence, controlled collaboration, Request Market, and clearly labelled
simulated concept panels.

See the repository [README](../README.md) for the product overview and
[`PRD.md`](../PRD.md) for the full feature contract.

## Stack

- Flutter with Dart `^3.11.5`
- Material 3 with a shared Soft Brutalist design system
- Provider/ChangeNotifier for application and server state
- GoRouter for onboarding guards and navigation
- Dio for REST and presigned S3 transfers
- `shared_preferences` for session and bounded offline read caches
- `image_picker` for avatar and Project Card media selection
- `fl_chart` for verified-activity visualisation

## Application structure

```text
lib/
├── api/        # shared Dio client and platform connection tuning
├── models/     # typed JSON contracts
├── screens/    # onboarding, home, projects, matches, requests, market, profile
├── state/      # Auth, Projects, Growth, Matches, Collaboration, and Market
├── theme/      # application theme, palette, typography, and motion
├── widgets/    # reusable Soft Brutalist components
├── config.dart # API base URL
├── main.dart   # provider wiring and application entry point
└── router.dart # route table and Trust Gateway guards
```

Views render Provider state and forward user actions; providers own remote
loading/data/error state and REST calls; models map the backend JSON contract.
Ephemeral presentation state, such as a selected tab or form controller, remains
inside the widget.

## Run locally

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Use the host address appropriate to the target:

| Target | Local backend URL |
|---|---|
| Android emulator | `http://10.0.2.2:8000` |
| iOS simulator / desktop / web | `http://127.0.0.1:8000` |
| Physical device | `http://<development-machine-LAN-IP>:8000` |

If `API_BASE_URL` is omitted, `lib/config.dart` uses the configured deployed
demo backend. The local override is recommended during development.

## Test and analyse

```bash
flutter analyze
flutter test
```

The test suite covers defensive model parsing, shared widgets, application
startup, and the narrow/wide navigation switch at the 700-pixel breakpoint.

The Android end-to-end flow lives in
[`integration_test/e2e_test.dart`](integration_test/e2e_test.dart). CI runs it
against a live FastAPI/PostgreSQL test stack and follows it with a fixed-seed
Monkey crawl.

## Important behaviour

- The router requires GitHub, LinkedIn, and primary-role onboarding in order.
- A primary-role switch changes the home emphasis, title, and accent colour; it
  does not create a second account or permission boundary.
- A 401 response from any API call clears the stale session globally.
- Successful unfiltered discovery, profile, and Growth Plaza reads are cached;
  writes are not queued while offline.
- Project screenshots use a three-stage presigned upload and never send the
  Builder Plaza JWT to Amazon S3.
- F9 Sandbox, AI Shortlist, Agent Access, and Proof-of-Work panels are simulated
  and visibly labelled.

## Release

The app version is declared in [`pubspec.yaml`](pubspec.yaml). GitHub Actions
builds release APKs after the required backend, Flutter, and Android E2E jobs
succeed. Android signing secrets are restored only inside the release job and
removed before later steps can access them.
