# Android diagnostic replay and vehicle reference

Vehicle Health shows live context and saved results. Open **View diagnostic
history**, select a drive, and expand a finding to see measured/expected values,
the threshold, context, and suggested inspection. The same analysis appears in
OBD recording details. The diagnostic code screen still reads the ECU directly.

On Android the app checks completed local runs at startup and account change,
after cloud restore, and after a recording is finalized. The application uses
the signed-in account's existing restore path. It scores in an isolate and saves
results in SQLite. Results remain available offline. Older recordings without
recorded ECU scan evidence are eligible for scoring once this phone has a
reference for their car. Their eligibility for fitting remains unverified.

For the first reference, keep the OBD adapter connected at recording start and
stop. Let both scans finish. The app requires successful MIL, stored, pending,
and permanent DTC reads. A code, illuminated MIL, or nonzero stored count blocks
training. Failures and unsupported scans also prevent fitting. Longer runs cover
more operating conditions. At least 30 usable five-second windows are needed
per signal and condition. Each car and account has a separate local reference.
The Yaris uses the packaged context forest when available. Other models use
the context rules. The reference is provisional and its threshold comes from
reference residuals. Later eligible drives are scored first. They can add
coverage and make bounded intercept adjustments. Existing slopes and thresholds
are preserved. Previously scored reports retain their original model version.
The reference and scan evidence currently stay on the phone that collected
them. A second phone restores the recordings and can establish its own
reference with a subsequent qualifying drive.

## Reproduce the results

Run the audit, train and held-out commands in LOCAL_DIAGNOSTICS.md. Then run:

```powershell
python -m ml.diagnostic_parity --csv-dir 'D:/7th/FYP/data/recs' --bundle ml/output/diagnostics/yaris-v1.json --out ml/output/diagnostics/parity
$env:AUTOPULSE_DIAGNOSTIC_REPLAY='ml/output/diagnostics/parity'
flutter test test/diagnostics --reporter expanded
```

Private recordings and generated fixtures stay under ignored paths. The parity
test verifies the exact windows and PIDs that were scored, predictions within
1e-8, and the PID/time of each event. It measures replay and scoring on the
machine running the test. On Android, debug logs show diagnostic replay time
including isolate dispatch. Use an account with a long restored drive, score it
with a reference on the phone, and read the `Diagnostic replay` log line. For a
first phone test, use a normal drive, then compare an external simulated replay.
Avoid introducing a fault into the physical car for a demo.

Holdout results come from the frozen research bundle fitted in Python. On-phone
references are fitted separately from scan-qualified drives and require their
own prospective evaluation. Report sensor prediction error, coverage, and
observed events on the holdout. Confirmed vehicle fault accuracy requires
independently diagnosed examples. Include the successful and missed simulation
cases in the evaluation.
