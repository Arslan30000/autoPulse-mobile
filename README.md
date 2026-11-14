# AutoPulseAI

## Verified cloud accounts and long recordings

The current backend uses **Firebase Authentication Spark** for verified email
accounts and password reset, **Supabase Free** for owner metadata and private
compressed recording chunks, and **SQLite** for offline capture and durable sync.
No purchased domain or custom SMTP service is required. Existing row-based cloud
runs and phone recordings are retained.

Existing users must create a verified account once using their existing email,
then prove access with their previous AutoPulseAI password to retain their cars
and runs. Read [the migration and phone testing guide](docs/free-cloud-backend.md)
before testing or switching app versions.

## Bluetooth implementation

Android Classic/SPP connection, supported-PID live readings, and local SQLite
recording are implemented on `feature/elm327-bluetooth`. See
[the architecture and phone-test guide](docs/obd-bluetooth.md).
BLE support is not part of this increment. Recording inspection and authenticated
cloud backup are implemented on `feature/supabase-pid-testing`; see the
[recording and sync guide](docs/recording-sync.md) for backend setup and validation.

Flutter application with vehicle-owner and mechanic interfaces. Android live
telemetry and connection status use the real OBD controller. Existing health
scores, diagnostic reports, and AI responses remain mock prototypes.

## Implementation status

- Paired Bluetooth Classic/SPP selection and Android permission handling.
- ELM initialization, serialized requests, fragmented-response buffering,
  supported-PID discovery, ECU-source selection, and unit conversion.
- Ten live parameter types, real RPM history, and explicit missing/stale states.
- Local SQLite session recording, storage error handling, and recording history.
- Shared owner/mechanic connection state and foreground-only lifecycle handling.
- Firebase verified email/password authentication and safe linking of existing
  Supabase accounts without changing their ownership UUIDs.
- Owner-scoped compressed recording backup, incremental active-run chunks,
  durable checkpoints, restart recovery and duplicate-safe retries.
- Paged, disk-staged restoration of both new compressed and legacy row-based runs.
- Persistent account-specific vehicle selection, recording details, per-PID graphs,
  acquisition quality reports, and full-session CSV sharing.
- Browser model-viewer asset fixes and startup/configuration regression tests.

Validation includes unit/widget tests, PostgreSQL ownership-policy checks and a
lossless 105,120-reading synthetic archive test. The Android app and Firebase
plugins pass compile-only validation. Real-car runs exist from earlier increments;
this backend upgrade still requires phone acceptance testing. The adapter must
support Classic/SPP; the ELM "v1.5" label alone does not establish this.

See [the phone-test guide](docs/obd-bluetooth.md) for setup, architecture,
limitations, and the next implementation increments.

AutoPulseAI is a mobile-first, edge-computing vehicle telemetry, performance, and diagnostic platform designed for the Pakistani Domestic Market (PKDM), with target platforms including the Toyota Yaris (XP150) and Mitsubishi Lancer (CS3A).

The product is designed around four core capabilities:

1. **Live Diagnostic Dashboard:** Connects to an ELM327 OBD-II adapter over Bluetooth to stream real-time parameters such as RPM, speed, throttle, coolant temperature, MAF, and fuel trims.
2. **Semantic RAG Technician:** Uses a Supabase `pgvector` backend containing embedded OEM Factory Service Manuals to translate diagnostic trouble codes (DTCs) into step-by-step mechanical repair guidance.
3. **Deterministic Physics Engine:** Fuses smartphone six-axis IMU data with OBD-II velocity through a Kalman filter to estimate live dynamic wheel horsepower without overloading the serial connection. (additional feature,if feasible)
4. **Transfer Learning ML Baseline:** Pre-trains on open-source Kaggle OBD-II datasets and fine-tunes on at least 10 hours of real-world driving to map vehicle-specific wear and degradation.

## CI/CD

GitHub Actions runs formatting, analysis, tests, PostgreSQL ownership checks and a
release APK build for the configured production, development and feature branches.
Successful runs publish `app-release.apk` for 14 days. It does not publish to a store.

## Git Flow and branching

- `main` contains production-ready releases.
- `development` is the integration branch for completed work headed toward the next release.
- `feature/<name>` branches are used for active development and should be created from `development`.
- Open a pull request from each feature branch into `development`. Promote reviewed, release-ready changes from `development` to `main` with a pull request.
- Merging into either `development` or `main` requires all GitHub Actions checks to pass. Configure branch protection rules in the repository settings to require the **Flutter checks and Android release** status check.

## Local developer setup

### Prerequisites

- Flutter stable with the Dart SDK version required by `pubspec.yaml`
- Java 17 for Android builds
- Android SDK and an emulator or device for manual app runs

### Configure environment

Copy `.env.example` to `.env` and provide the backend values required for your local environment:

```dotenv
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

Keep `.env` and Android signing credentials private; they are excluded by `.gitignore`.
Never commit administrator credentials. Release builds currently use the project's
debug signing configuration; configure a release keystore before store distribution.

Normal builds use the bundled public Supabase and Firebase identifiers. Supabase
build definitions override the bundled project; supply both URL and a public key.
Use `--dart-define=AUTOPULSE_OFFLINE=true` for an explicit offline build. An empty
`.env` is not an offline switch because bundled defaults exist. Firebase verifies
emails; Supabase enforces owner policies. Health/AI screens remain prototypes.
See [the deployment record](docs/free-cloud-backend.md) before changing projects.

```powershell
flutter run -d edge --web-port 8766 --dart-define-from-file=.env
flutter run -d YOUR_ANDROID_DEVICE_ID
```

`.env` is read at build time, not loaded as an application asset. Restart/rebuild
after changing its values. VS Code launch configurations pass it automatically.

### Install and check

From the repository root, install dependencies and run the same checks used by CI before pushing:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

To build the Android release APK locally:

```bash
flutter build apk --release
```

The artifact is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Accounts and vehicle restoration

Saved runs default to newest first and support date/duration sorting in either
direction. See [saved-run sorting and integration](docs/saved-run-sorting.md).

Live ECU trouble-code scanning, category filters and foreground alerts are
available from Diagnostics and Live. See [DTC behavior and testing](docs/live-dtc-diagnostics.md).

Sign in or create an owner account, or continue offline. Settings supports profile
editing, adding/selecting cars, viewing saved runs and syncing account data.
Owned active runs back up complete chunks when online; their final tail uploads
after stopping. Completed cloud runs restore on sign-in without a whole-run Dart
memory buffer. Recording remains foreground-only.
Existing local recordings are retained. See [account setup and storage behavior](docs/accounts-and-sync.md)
for environment setup, migration deployment, offline behavior and update precautions.
