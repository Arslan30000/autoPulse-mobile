# OBD recording inspection and cloud backup

The current setup is documented in [Verified accounts and long recording
storage](free-cloud-backend.md). The Firebase/Supabase migrations listed there
were deployed on 2026-11-07; do not replay them into the existing project.

## Use

1. Sign in/create and verify an account, or continue offline.
2. Add/select a car and connect a paired Android Classic/SPP adapter.
3. Start/stop recording from Live; open OBD recordings to inspect saved runs.
4. Inspect each PID's value graph, quality counts, response rate, latency and gaps.
   Missing readings retain null values. Observed app response rate is not ECU
   sampling frequency. The full-session summary includes every recorded attempt.
5. Export a complete CSV through the Android share sheet. Export includes the
   individual asynchronous samples and their quality, not fabricated snapshots.
6. Owned runs back up automatically when online. Existing offline runs require
   explicit ownership confirmation with their Upload trip button after stopping.
7. Use Settings sync or Retry for pending uploads; sign in on another phone and
   open OBD recordings to restore completed cloud runs.

## Formats and durability

`obd_recording_sessions` describes each run. New `gzip-json-v1` runs place raw data
in private Storage objects referenced by `obd_recording_chunks`. Legacy `rows-v1`
runs continue reading `obd_recording_samples`. `telemetry_readings` is not used by
this asynchronous recorder. Both formats retain original PID/value/unit/quality,
UTC request/receive timestamps, latency, ECU source and sample order.

SQLite commits before cloud work. Uploads use immutable object IDs, acknowledged
sample cursors, integrity checks and server-side completion. Restores use bounded
pages and hidden SQLite staging; only the expected complete sample count becomes
visible. Account checks after awaits prevent accepting a result for a different
owner. Existing recordings are retained through schema upgrades.

## Limits and acceptance

The recording bucket is private and free capacity is finite. Settings shows the
850 MB shared recording budget; quota/network errors retain local data and CSV
export. Keep the app in the foreground and screen awake during collection. This
change does not provide a background acquisition service.

Before merge, test verification/linking, in-place update preservation, offline
collection, reconnect sync, interrupted uploads/downloads, second-phone restoration,
account isolation and an actual long car session. Synthetic scale tests and
automated ownership tests do not replace physical-phone acceptance.
