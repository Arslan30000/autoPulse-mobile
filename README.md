# AutoPulseAI


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
