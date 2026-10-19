# AutoPulseAI UI refresh

The shared theme now uses slate (#1A303C), teal (#00ACC7), rounded surfaces,
white headings, and readable secondary text. Existing owner and mechanic screens
inherit this theme. Source artwork is supplied by the project owner.
Inter font weights are bundled with their OFL license so typography works offline.

- Welcome, adapter setup, and assistant introduction appear before login on a
  fresh install. Completing the third page persists `onboarding_complete_v1`.
  Existing signed-in users and installations with a selected car keep their
  direct entry path. Signing out does not reset onboarding.
- Registration requires name, email, an eight-character password, and matching
  confirmation. Login continues to support existing passwords. Both modes retain
  guest access and the existing account/vehicle restoration behavior.
- Password recovery requests an email token, verifies it as a recovery OTP, and
  updates the password. In Supabase **Authentication → Email Templates → Reset
  Password**, install [the recovery email template](../supabase/templates/recovery.html).
  It exposes `{{ .Token }}` for entry in the app without depending on deep links.
  Email delivery still requires the project's SMTP configuration; this change
  does not alter hosted authentication settings.
- Home uses the existing car geometry with revised titanium paint, glass,
  lighting, and shadows in `car-showroom.glb`. The original GLB is retained.
  The inline model ignores pointer input and has no automatic rotation, so it
  cannot capture page swipes. Explore 3D opens a separate rotatable viewer.
  The model is illustrative rather than make/model specific.
- Only RPM, speed, and coolant use gauges. Other ECU readings remain numeric
  cards. The gauges honor unsupported, stale, timeout, invalid, waiting, and
  disconnected states; missing data never appears as a real zero reading.
- Health, diagnostics, assistant, and report examples retain their existing data
  sources and explicitly identify sample insights. Home has no health score.
- Navigation mounts tabs on first visit and disables animation tickers when a
  tab is hidden.

Validation: 90 tests pass, static analysis is clean, and the web and ARM64 Android
debug builds compile. The phone-size screenshots use the desktop fallback for
the car preview; actual 3D appearance, touch interaction, and Bluetooth require
an Android device check.

Run `flutter test` for regression coverage. UI checks cover compact and regular
phone widths. To regenerate review screenshots under `docs/ui`, run:

```powershell
flutter test test/ui_refresh_test.dart --dart-define=UPDATE_UI_PREVIEWS=true
```
