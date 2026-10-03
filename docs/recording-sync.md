# OBD recording inspection and cloud backup

This increment extends the Bluetooth recorder with persistent vehicle identity,
account authentication, recording inspection, acquisition quality reports, CSV
export, and resumable Supabase backup. Physical adapter validation is still required.

## Configure a development Supabase project

1. Apply `supabase/migrations/20261003000000_owner_vehicle_ingestion.sql` if it
   is not already applied, then apply `20261004000000_obd_recording_sync.sql`.
   Use the Supabase SQL editor or your normal migration workflow. Do not replay
   migrations already recorded as applied.
2. Enable email/password authentication. With email confirmation enabled, confirm
   the account using the email link and then sign in in the app. Registration does
   not imply authentication until Supabase returns a session.
3. Supply `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` (or `SUPABASE_ANON_KEY`)
   in the ignored `.env` file, using the existing `.env.example` as a template.
   Only a public client key belongs in a mobile build. Do not disable RLS.
4. Rebuild the Android app with configuration:

```powershell
flutter pub get
flutter run -d DEVICE_ID --dart-define-from-file=.env
```

The app also works with no Supabase configuration. Local Bluetooth acquisition,
inspection, and CSV sharing do not require an internet connection or account.
The migration is committed as code; committing it does not deploy it to your project.

## Use the feature

- Choose a role, sign in or continue offline, and save your vehicle details.
- Connect a paired Android Bluetooth Classic adapter from Add Vehicle or Live.
- Start and stop recording from Live. The history icon opens **OBD recordings**.
- Tap a recording for its duration, per-PID graph, response rate, latency, missing
  data counts, and full-session quality summary. Refresh an active recording to
  inspect newly saved samples.
- Use **Export CSV** on a finished recording to share the complete measurement
  file through Android's share sheet. Export does not invent values for missing PIDs.
- Use **Back up** on a finished recording. An offline session requires explicit
  confirmation before it is permanently assigned to the signed-in account.
- **Retry backup** retries one recording. **Retry queued backups** retries requests
  already made. Transient network failures retry with bounded exponential delay
  while the app is in the foreground, and queued uploads resume after restart or
  sign-in. New local recordings are not automatically opted into cloud upload.
- Manage the account from the history toolbar or **Profile → Cloud account**.
  Signing out disconnects the adapter and finalizes the active recording first.

## Storage and ownership

SQLite schema version 2 upgrades the existing version 1 database without dropping
sessions or samples. Every session has a persistent UUID; samples retain their
original SQLite IDs. Vehicle selections persist per account and separately for
offline use. Local vehicle aliases keep offline acquisition usable after older
sessions have been assigned to an account. Legacy vehicle make information that
was never stored is explicitly represented as `Unknown`.

The server tables are `obd_recording_sessions` and `obd_recording_samples`. A cloud
sample is identified by `(session_id, sample_id)`. It contains the original PID,
nullable value, stored unit, quality, UTC request/receive timestamps, monotonic
response latency, and ECU source. The old `telemetry_readings` snapshot table is
not used for this asynchronous measurement stream.

The new migration adds `vehicles.owner_id` and owner-scoped RLS policies. Composite
foreign keys enforce the same owner across vehicle, session, and samples. Existing
unowned cloud vehicles stay inaccessible until deliberately migrated. Other legacy
tables retain their existing closed policies; this feature does not enable mock
health, report, diagnostic, or AI data ingestion.

Only completed sessions upload. The worker upserts the vehicle and session, then
inserts sample batches of 250 with duplicate rows ignored. Each acknowledged batch
advances a durable local checkpoint. A lost acknowledgment replays the same keys;
it does not overwrite measurements or create additional rows. The completion RPC
checks the server sample count before marking the session uploaded. HTTP errors
leave local data intact. An account change interrupts the worker before the next
batch or checkpoint; another account cannot claim a previously owned session.

Cloud history is backed up in Supabase; this increment's app history reads the
local database. Cross-device downloading and background services are separate
future increments. A process-killed session remains open/interrupted and cannot
be uploaded or exported until a future recovery flow deliberately finalizes it.

## Understanding the quality report

Observed PID rate is `(attempt_count - 1) / (last_received - first_received)`.
It measures app response throughput, not the ECU's sensor sampling frequency.
No rate is reported for fewer than two distinct timestamps or when the phone clock
moves backwards. Missing/invalid replies are counted rather than converted to zero.
An unrecorded PID does not establish that it is unsupported. Latency comes from
the controller's monotonic stopwatch. Request/receive timestamps are phone times,
not exact ECU acquisition times.

Graphs show the latest 600 attempts for a selected PID, preserve negative values,
and break at invalid/missing readings or gaps over six seconds. Full-session metrics
and CSV export read all pages; they are not restricted to the graph preview. CSV
text is escaped and spreadsheet formula prefixes are neutralized; numeric fuel
trims remain numeric.

## Verification without a vehicle

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

All synthetic samples live under `test/`; the app never inserts demo measurements
into a real recording. Tests cover SQLite upgrade/persistence, paging, account
isolation, durable checkpoints, lost acknowledgments, finalization retries, one
upload worker, CSV export, full-session metrics, account registration semantics,
Supabase request mapping, and recording screen navigation.

CI runs the schema/RLS tests against a disposable PostgreSQL 17 service. The
`supabase/tests/auth_fixture.sql` file is a CI-only stand-in for Auth and must never
be applied to an actual Supabase project. The transactional RLS test checks owner
spoofing, cross-owner foreign keys, anonymous reads, duplicate replay, incomplete
uploads, and finalization. CI is enabled for `feature/supabase-pid-testing` pushes;
no merge is required to run it.

## Physical phone and cloud acceptance test

1. Collect a short stationary session on the actual adapter and vehicle.
2. Compare a few readings to an independent scanner where available. Record which
   PIDs are supported and the rates/latencies actually observed.
3. Stop recording, reopen details, and verify CSV row count equals saved sample count.
4. With the migration applied, sign in and back up the session. Check the server
   row count and that a second backup/retry creates no duplicate samples.
5. Interrupt an upload by removing internet access, restore it, and retry. Local
   samples must remain intact; the recording should eventually show **Backed up**.
6. Sign in as a second test account. The first account's cloud rows must be invisible.
7. Test denied Bluetooth permission, adapter loss, and backgrounding separately from
   cloud failures. Follow the stationary testing guidance in `obd-bluetooth.md`.

## API references

- [Supabase Flutter upsert](https://supabase.com/docs/reference/dart/upsert)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Flutter password authentication](https://supabase.com/docs/reference/dart/auth-signinwithpassword)
