# Accounts, cars and saved runs

## Running the Android app

Use VS Code's **AutoPulseAI (Supabase)** launch configuration, or:

```sh
flutter run --dart-define-from-file=.env
```

The root `.env` must contain `SUPABASE_URL` and `SUPABASE_ANON_KEY`
(or `SUPABASE_PUBLISHABLE_KEY`). Only a public client key belongs in this file.
Environment values are compiled into the app: fully restart/rebuild after changing them.
The **AutoPulseAI (offline)** VS Code configuration builds without cloud services.

## Account flow

- New installations open Sign in, with Create account and Continue offline.
- Signup collects name, email and password. Supabase Auth handles credentials;
  `profiles` mirrors the owner's display name. Passwords are never stored in app tables.
- If email confirmation is enabled, confirm the email before signing in. The app
  does not claim that an unconfirmed signup has a session.
- A remembered account with a cached car opens Home immediately. A fresh sign-in
  restores cars and uploaded runs, then opens Home when a car exists.
- An account with no cars opens Add Vehicle. Bluetooth pairing is available later
  through Live or Settings; account onboarding does not require an OBD adapter.
- Settings provides profile editing, car selection/addition, recording history,
  manual sync, connection controls, privacy information and sign-out.

## Storage and offline behavior

Vehicles and selected-car preferences are cached separately for each account and
for offline use. The previous single-car preference key is preserved and migrated
into the car collection without discarding it. The SQLite database filename and
schema version remain unchanged. Existing phone recordings are not replaced or deleted.

Cars and completed runs made while signed in back up automatically in the
foreground. Sync retries every 30 seconds and when the app resumes; Settings
also exposes a manual sync action. Recording goes to SQLite first, so loss of
internet does not stop Bluetooth capture. Cloud backup requires connectivity.
Only finished recordings are uploaded; individual live PID requests do not wait
for Supabase. Keep the app open to finish syncing before changing devices.

Older recordings made without an account remain available on the original phone.
Their upload button explicitly assigns them to the signed-in account; they are
not silently assigned to whichever account signs in next. Once uploaded, those
runs restore on another phone using the same account. Cloud restoration uses
paged requests, validates the complete sample count, and imports each finished
run atomically. The cloud recording UUID prevents duplicate imports. Downloaded
samples remain viewable without internet. Sample pages are currently collected
in memory per run before import; very large individual recordings may require a
future disk-staging implementation.

Signing out retains cached data but hides that account's runs from other accounts.
Continuing offline uses the separate offline car selection. Installing an update
with the same Android application ID and signing certificate normally retains
SQLite and preferences. Uninstalling or clearing app storage removes local data;
export any runs that have not yet been uploaded before doing that.

## Supabase migrations

Apply, in order, to a fresh project:

1. `20261003000000_owner_vehicle_ingestion.sql`
2. `20261004000000_obd_recording_sync.sql`
3. `20261006000000_account_profiles.sql`

For the current AutoPulseAI project, the initial ingestion schema was already
present. Recording/account ownership and profile migrations were applied through
the Supabase SQL editor on 2026-10-06. Do not reapply these non-idempotent migrations
to that database. SQL editor application does not automatically populate the
Supabase CLI migration history; reconcile history before using CLI migrations
against this existing project.

Row-level security limits cars, profiles, sessions and samples to their owner.
The client cannot choose another user's profile ID. The Auth trigger maintains
profile changes, with a fixed search path and no direct client execute privilege.
The sample/session foreign keys prevent cross-account vehicle associations.
Other original mock-feature tables retain their existing restrictive policies;
this work does not persist fabricated diagnostic or AI results.

CI applies all three migrations in a disposable PostgreSQL database and checks
recording and profile ownership policies. Never deploy `supabase/tests/auth_fixture.sql`
to Supabase: it only supplies minimal Auth stubs for CI.

## Signup email delivery

Email authentication and new signups are enabled in the live project. Email
confirmation was disabled at the project owner's request on 2026-10-06 for testing.
Users can sign up with an email and password and sign in immediately without SMTP.
Supabase Auth stores their email, but this testing configuration does not verify
that they own that address.

Before a public release, enable email confirmation and configure a custom SMTP
sender in Authentication > Emails > SMTP Settings.
See https://supabase.com/docs/guides/auth/auth-smtp. Keep SMTP credentials on the
backend; never put them in the Flutter environment or repository. Enter the SMTP
password directly in the dashboard. The app also handles signup responses that
require email confirmation.
