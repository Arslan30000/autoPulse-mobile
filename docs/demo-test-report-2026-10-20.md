# AutoPulseAI demo test report — 20 October 2026

Software verification passed after the fixes below. This is **not a physical Bluetooth or vehicle validation certificate**. No Android phone appeared in `adb devices -l`, and no OBD adapter/vehicle was available to this session. Health scoring, diagnostic/anomaly inference, and AI answers remain sample-data prototypes.

## Verified results

| Area | Result | Evidence and boundary |
| --- | --- | --- |
| Full regression suite | **152 passed** | `flutter test --no-pub --coverage`. The live backend test is skipped by default and was executed separately. Baseline before this audit: 96 passed. |
| Static analysis | **No issues** | `flutter analyze --no-pub` after the final fixes. |
| Real backend integration | **Passed** | Real signup/password login, profile update and database trigger, recording upload/completion RPC, duplicate replay, signout/relogin, cloud download, SQLite restoration, and isolation between two synthetic accounts. |
| Bluetooth protocol/controller | **Passed with simulated transport** | Fragmented ELM replies, command serialization, initialization/rejection, PID discovery, read-only command allowlist, malformed/NO DATA replies, timeouts, write/link failure, reconnect, cancellation, recording and lifecycle handling. Native Android bridge also compiled in the APK. Radio/pairing/socket behavior on a phone is unverified. |
| Live monitor | **Passed with simulated acquisition** | Actual controller and ELM parser feed the live widget. `1A F8` produces 1726 RPM; speed byte `80` produces 128 km/h; coolant byte `80` produces 88 °C. Changing RPM bytes to `2E E0` updates the gauge/graph to 3000 RPM. |
| Gauge needles | **Passed raster checks** | Minimum, 25%, 50%, 75%, maximum positions for RPM, speed and coolant; negative coolant scale; animation; over-range clamping; disconnected parking; NaN/infinity protection. These check displayed scale mapping, not ECU calibration. |
| Graphs | **Passed** | Timestamp-based points, missing-value gaps, negative trims, labels/tooltips, zoom/reset, pause/resume, new-connection reset, and chronological cloud restoration. Pausing the graph leaves acquisition and recording active. |
| Recordings | **Passed** | Real SQLite recording/finish, failure handling, pagination, statistics, full CSV export, cloud retry/checkpoints, ownership, duplicate-safe upload, and restore. Simulated bytes were exercised through acquisition → SQLite → analysis → CSV. |
| Screen layouts | **32 route/width cases passed** | Sixteen screens at 320 and 414 logical pixels, using bundled Inter fonts, including scrolling. Existing tests additionally cover onboarding/login keyboard and larger text, navigation/back, and live layouts at 320/412/1024. Initial placeholder-font failures were not treated as proof of real-device rendering defects. |
| Report controls | **Passed** | Four formerly inactive controls now open selectable report text or invoke platform sharing. Share errors show a recovery message. These are sample text reports, not generated PDFs or real vehicle diagnoses. |
| Android release | **Built** | ARM64 `build/app/outputs/flutter-apk/app-release.apk`, approximately 24.3 MB, with local backend configuration. |
| Web release | **Built** | `build/web`, built with `--no-web-resources-cdn`; compilation and Wasm dry run passed. No claim of physical Bluetooth support in a browser. |

Environment: Flutter 3.47.6 stable, Dart 3.13.5, Windows. Final APK SHA-256:

```text
CE019973C70FD98B4D3BFEDA0DB24D12AC5CB7B04A964AC51B80E07CE2266339
```

## Errors found and corrected

1. **Cloud recordings could restore backwards or lose/repeat samples across pages.** The installed PostgREST client defaults to descending order. The old `sample_id > cursor` query relied on the default, so a seven-sample fixture returned `[7,6,5,7,6]`. The downloader now explicitly orders ascending, checks cursor progress, and is shared with account restoration. Import also sorts the payload by acquisition ID before assigning local IDs. Regression tests reproduced both reversed import and broken pagination before the fixes. A live backend download and restore then passed. This prevents new incorrect imports; previously cached reversed recordings are not automatically rewritten by this change.
2. **Disconnect could fail to cancel an early connection attempt.** Connection ownership/status was established only after asynchronous socket cleanup. An early Disconnect could be overwritten by a later successful connection. Attempts now claim their generation immediately and check cancellation after cleanup and initialization.
3. **Duplicate connect calls could overlap.** The same early cleanup window allowed a second attempt. Busy state is now synchronous; the duplicate-call regression confirms only one transport connect occurs.
4. **A delayed recording start could attach to a different connection.** It checked only whether the controller was ready when storage returned. It now also checks the connection generation and finishes the cancelled session instead of activating it.
5. **Disconnect could return before an already-running recording stop finished.** Concurrent callers now await the same finalization future, preserving the accepted-write flush and finish ordering.
6. **Non-finite gauge values could crash the screen.** The needle guarded NaN/infinity, but the displayed number and semantics still called `round()`. All representations now use the same finite-value check and show missing data safely.
7. **A paused graph could survive into a new drive.** Graph state now resets when the connection history is cleared or the parameter, origin, or graph mode changes.
8. **Several layouts had avoidable width/height constraints.** Role selection scrolls; vehicle preview/history text and shared headings/evidence labels can fit their available width. The route sweep uses the real app fonts to avoid attributing placeholder-font artifacts to production.
9. **Four report buttons had empty handlers.** Report preview and sharing are implemented, with selectable text and a recoverable share error. Synthetic insight screens also show sample-data notices when opened directly.

Drive D: was initially almost full, preventing Flutter test compilation. Only the project's generated `build/app/intermediates` cache was removed to make room; existing APKs and source files were preserved. Pre-existing branding/home-screen changes were retained.

## Coverage

Line coverage from the full offline suite, excluding the separately run live integration test:

| Component | Covered lines |
| --- | ---: |
| OBD parser | 100% |
| Gauge painter/widget | 100% |
| Telemetry chart | 99.3% |
| Cloud recording repository | 97.4% |
| ELM client | 95.1% |
| SQLite recording repository | 94.0% |
| OBD controller | 93.9% |
| Login screen | 89.3% |
| Recording sync service | 76.1% |
| Whole measured app | 76.7% (3924 / 5116 lines) |

Coverage shows which source lines executed. It does not establish hardware compatibility, timing/throughput on a real adapter, or vehicle measurement accuracy.

## Backend audit details

The configured project's auth endpoint was reachable, password login enabled, signup enabled, and email autoconfirm enabled. A synthetic invalid login was rejected. Anonymous requests to the private tables were denied.

Two dedicated synthetic accounts were created/reused for integration testing; **existing user accounts and their data were not modified**. Labelled synthetic vehicles and recording fixtures remain under those test accounts because the app's authenticated role has no delete policies. Credentials are stored only in the ignored `.dart_tool/live-demo-audit-accounts.json`; no credentials or session tokens are included in this report. The run summary is `.dart_tool/live-backend-result.json`.

Cross-account reads of another test owner's profile, vehicle, recording session and samples returned no rows. Attempts to insert a car owned by the other account or complete the other account's recording failed. A three-sample upload preserved 1726 RPM, a legitimate zero speed, and an explicit null/NO DATA temperature; replaying the same upload did not add duplicate rows. Download through the production pagination helper and restoration into fresh SQLite preserved values and ordering.

Email delivery, recovery email templates/codes and confirmation links were **not exercised against a mailbox**. Their UI/API sequencing is covered by mocked auth tests. The current recovery screen requires the email's recovery token/code; the configured email template must expose that code for this flow. Real session restoration after killing/reinstalling the phone app also remains a manual check.

## Required phone/adapter rehearsal before the demo

1. Connect the Android phone by USB, enable USB debugging and authorize this PC. Confirm that `adb devices -l` lists it as `device`.
2. Install the final ARM64 release APK. Use a compatible phone; ARM32-only devices require a different build. Sign in with the actual demo account, restart the app and verify its car selection and session restore.
3. Pair the powered Bluetooth Classic/SPP adapter in Android settings and close other scanner apps. BLE-only and Wi-Fi adapters are not supported by this transport.
4. With the car stationary and ignition on, select the paired adapter and grant Nearby devices permission. `LIVE` must appear only after ELM initialization and ECU PID discovery succeed.
5. Compare RPM, speed and coolant against an independent scanner/reference. At idle, confirm sensible RPM and zero vehicle speed. Change RPM while stationary and confirm the number, needle and RPM graph move together. Unsupported/no-data parameters must remain missing rather than showing invented zeros.
6. Pause the graph, start a short recording, change RPM, then resume. The graph should resume with the acquired data and recording must have continued while paused. Stop recording and inspect Saved runs, the PID graph and exported CSV.
7. Repeat after disconnect/reconnect, adapter power loss, Bluetooth off, denied permission, and background/resume. Values must stop being represented as current, and active recordings must finish safely. Recording is foreground-only by design.
8. Upload an actual short run, sign out/in, and verify cloud restore. This is the remaining combined hardware/account rehearsal; synthetic cloud integrity has already passed.

Do not present sample health scores, sample DTCs/anomaly inference, AI responses or sample drive reports as diagnoses derived from the connected vehicle. The implemented live product path is Bluetooth acquisition, ten Mode 01 PID types, gauges/history, local recording/CSV and authenticated backup/restore. Live DTC reads, RAG/ML diagnosis, BLE, iOS Bluetooth, background acquisition and PDF report generation are not implemented by this audit.

## Reproduce the software checks

```powershell
flutter --no-version-check analyze --no-pub
flutter --no-version-check test --no-pub --coverage
./tool/check_demo_backend.ps1
flutter --no-version-check test --no-pub test/live_backend_audit_test.dart --dart-define=LIVE_BACKEND_AUDIT=true
flutter --no-version-check build apk --release --target-platform android-arm64 --dart-define-from-file=.env
flutter --no-version-check build web --no-pub --no-web-resources-cdn --dart-define-from-file=.env
```

The opt-in live test creates/reuses synthetic accounts and writes synthetic cloud fixtures. Its signup guard requires email autoconfirm so it cannot send confirmation emails. Normal `flutter test` runs skip that test and make no live-backend mutations. Detailed suite and coverage logs are in `.dart_tool/demo-test.log`, `.dart_tool/demo-coverage-summary.json`, and `coverage/lcov.info`.
