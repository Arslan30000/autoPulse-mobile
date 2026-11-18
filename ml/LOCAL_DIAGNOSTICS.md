# Local recording diagnostics

Use one folder of phone CSV exports per vehicle. Keep bench fixtures and
duplicates outside that folder. Commands run from the repository root in
PowerShell with Python 3.12 or later. The diagnostic workflow uses the standard
library, including the exported context forest interpreter.

## Audit, train and evaluate

```powershell
$data = 'D:/7th/FYP/data/recs'
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

## View in the app

Run the Flutter app locally. Open Vehicle Health for live driving context.
Open the report JSON on your device, copy its contents, and tap **Paste
diagnostic report**. The view shows check coverage and expands findings into
measured evidence and suggested inspection steps. It labels simulated and
training runs. The imported report is kept for the current screen session.
The score mock has been replaced here with check coverage and findings.

The diagnostic branch removes the scheduled remote worker from its workflow.
The schedule on the default branch changes when this workflow is merged there.
