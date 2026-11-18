# Local recording diagnostics

Use one folder of phone CSV exports per vehicle. Keep bench fixtures and
duplicates outside that folder. Commands run from the repository root in
PowerShell with Python 3.12 or later. The diagnostic workflow uses the standard
library, including the exported context forest interpreter.

## Fetch recordings from Supabase

Copy the car's `id` UUID from the `vehicles` table in the Supabase dashboard.
The fetch command uses the same legacy `service_role` JWT as the earlier
worker. Enter it in the masked PowerShell prompt below. Use a trusted laptop
and keep this credential out of the repo and the Flutter app.

```powershell
$env:SUPABASE_URL = 'https://ffedjcrehudjwvdogqiw.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY = Read-Host 'Supabase legacy service_role key' -MaskInput
$data = 'ml/data/yaris-cloud'
try {
    python -m ml.diagnostics fetch --vehicle-id 'PASTE-CAR-UUID' --csv-dir $data
} finally {
    Remove-Item Env:SUPABASE_SERVICE_ROLE_KEY
}
```

Use PowerShell 7. Repeat the fetch after uploads complete to pick up new runs.
It fetches both cloud storage formats, verifies the recordings, saves phone-compatible
CSVs, and skips intact cached files. Use a dedicated folder per car. A partial
fetch reports individual failures and returns an error. Resolve those failures
before training. The cache index includes completed sessions with zero samples,
which cannot be scored. Review the cache and remove any bench or test runs from
the **training input** by copying the eligible CSVs into a separate folder.
Fetch is read-only and runs on demand from your laptop.

## Audit, train and evaluate

```powershell
$data = 'ml/data/yaris-cloud' # Or your audited folder of eligible CSVs.
$out = 'ml/output/diagnostics'
python -m ml.diagnostics audit --csv-dir $data --out "$out/audit.json"
python -m ml.diagnostics train --csv-dir $data --vehicle yaris --out "$out/yaris-v1.json"
python -m ml.diagnostics score --csv-dir $data --vehicle yaris --bundle "$out/yaris-v1.json" --test --out "$out/heldout.json"
```

Review audit session IDs, durations and PID quality counts. With three or more
recording start dates, the last date is held out, the preceding date calibrates
the candidates, and earlier dates fit them. With fewer dates the bundle is
provisional. For a first-drive baseline, copy one reviewed recording into a
separate folder and train on it, then score a later export without the
`--test` switch. Use a separate directory for prospective drives to avoid
accidentally reporting training performance.

The bundle records context model, thresholds, session fingerprints and
per-signal calibration comparisons for context median, context ridge and pooled
ridge. Context ridge is the prespecified detector. Compare MAE alongside
coverage and alerts per scored hour. Small context groups abstain. Thresholds
that lack sufficient independent calibration use in-sample residuals and record
their independent calibration count. Coolant and intake checks group by time
since recording started as a proxy for thermal phase. Fuel trim findings use
context-conditioned deviations. They do not establish closed-loop status.

## Test a simulated event

Choose a session from the held-out report and a sustained stretch of valid,
stable measurements. The following example changes MAF by +8 g/s for 60 seconds
starting 120 seconds after the first received sample. Adjust the interval to the
chosen recording. Compare the same interval in the untouched report.

```powershell
$id = 'PASTE-HELD-OUT-SESSION-ID'
python -m ml.diagnostics score --csv-dir $data --vehicle yaris --bundle "$out/yaris-v1.json" --test --session $id --inject 0x10 8 120 60 --out "$out/simulated.json"
```

Read the event's observed/expected values and delay. A stressed interval may
abstain if the context or signal is unsupported. Repeat with several intervals,
offset sizes and short spikes, recording misses too. Keep simulated results
separate from independently confirmed vehicle faults.

Optional DTC evidence can be supplied via `--dtc-json scan.json`, keyed by
session ID. Each item needs `code`, `scan_time` (ISO 8601 with timezone), and
`status` from an actual scan. Only supply DTCs associated with that recording.
The report correlates related codes and preserves scan time and status. Missing
scan evidence does not imply the ECU reported no codes.

## Update a vehicle reference

```powershell
python -m ml.diagnostics adapt --csv-dir 'D:/path/to/new-reviewed-csvs' --vehicle yaris --bundle "$out/yaris-v1.json" --reviewed-reference --out "$out/yaris-v2-candidate.json"
```

Use this command after checking signal quality and relevant DTC history. The
command scores against the existing reference first and rejects drives with
sustained findings. It adds supported contexts and bounds intercept changes.
Compare v1 and v2 on retained recordings before using the candidate. Keep v1
for rollback. The previous validation in the candidate bundle belongs to the
original fit. Run a fresh holdout comparison before claiming improved accuracy.

## View on Android

The app stores its own results and builds a reference from scan-qualified
recordings. Open Vehicle Health or Diagnostic History for the results. This
local Python workflow remains available for research and reproducible replay.
See [the Android diagnostic guide](ANDROID_DIAGNOSTICS.md) for the complete
app flow and parity commands.

The diagnostic branch removes the scheduled remote worker from its workflow.
The schedule on the default branch changes when this workflow is merged there.
