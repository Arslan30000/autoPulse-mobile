# AutoPulseAI

## Bluetooth implementation

Android Classic/SPP connection, supported-PID live readings, and local SQLite
recording are implemented on `feature/elm327-bluetooth`. See
[the architecture and phone-test guide](docs/obd-bluetooth.md).
BLE support and cloud recording synchronization are not part of this increment.

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
- Optional Supabase client initialization; no telemetry cloud sync yet.
- Browser model-viewer asset fixes and startup/configuration regression tests.

Software validation: 36 tests passed, static analysis clean, Android debug APK
and web builds succeeded. A physical adapter has not yet been tested. The adapter
must support Classic/SPP; the ELM "v1.5" label alone does not establish this.

See [the phone-test guide](docs/obd-bluetooth.md) for setup, architecture,
limitations, and the next implementation increments.

AutoPulseAI is a mobile-first, edge-computing vehicle telemetry, performance, and diagnostic platform designed for the Pakistani Domestic Market (PKDM), with target platforms including the Toyota Yaris (XP150) and Mitsubishi Lancer (CS3A).

The product is designed around four core capabilities:

1. **Live Diagnostic Dashboard:** Connects to an ELM327 OBD-II adapter over Bluetooth to stream real-time parameters such as RPM, speed, throttle, coolant temperature, MAF, and fuel trims.
2. **Semantic RAG Technician:** Uses a Supabase `pgvector` backend containing embedded OEM Factory Service Manuals to translate diagnostic trouble codes (DTCs) into step-by-step mechanical repair guidance.
3. **Deterministic Physics Engine:** Fuses smartphone six-axis IMU data with OBD-II velocity through a Kalman filter to estimate live dynamic wheel horsepower without overloading the serial connection. (additional feature,if feasible)
4. **Transfer Learning ML Baseline:** Pre-trains on open-source Kaggle OBD-II datasets and fine-tunes on at least 10 hours of real-world driving to map vehicle-specific wear and degradation.

## CI/CD

GitHub Actions runs formatting checks, static analysis, tests, and a release APK build for pushes and pull requests targeting `main` and `development`. Successful runs publish `app-release.apk` as a downloadable artifact for 14 days.

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

Keep `.env` and Android signing credentials private; they are excluded by `.gitignore`. Never commit production secrets. The current workflow builds an unsigned-by-project-configuration release APK and does not publish to an app store.

The app now initializes the Supabase Flutter client when both values are provided.
Supply the publishable/anon key only, never a service-role or secret key.
An empty configuration keeps the mock prototype usable. Screens still use mock
services; client initialization does not itself implement authentication or ingestion.
The data-ingestion branch migration enables RLS without access policies, so owner
authentication and owner-scoped policies are required before app CRUD can work.

```powershell
flutter run -d edge --web-port 8766 --dart-define-from-file=.env
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=.env
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
