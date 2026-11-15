# Vehicle anomaly baseline (experimental)

This branch adds a reproducible **vehicle-specific airflow deviation** pipeline. It does not classify or confirm mechanical faults. DTCs remain independent ECU evidence. The phone continues to record offline; the server analyzes completed cloud runs.

## Technologies and model choice

| Part | Technology | Reason |
| --- | --- | --- |
| Collection | Existing Flutter/SQLite recording code | Preserves offline recording and the app's current DTC behaviour. |
| Cloud input | Supabase `obd_recording_sessions`, legacy sample rows, and private gzip chunks | Reads the existing immutable uploads without copying raw telemetry into another table. |
| Job queue/results | PostgreSQL tables and completion trigger | Enqueues once after a verified upload; gives the debug screen a durable status. |
| Worker | Python 3.12 standard library, GitHub Actions | Small CPU-only models and no paid training server. The scheduled workflow processes queued runs; `workflow_dispatch` runs it on demand. |
| Candidate models | Ridge airflow regression; operating-regime median; ridge with a public prior | Compare interpretable approaches before selecting by held-out Yaris MAF prediction error. |
| Debug view | Flutter Settings → Model diagnostics, in debug builds | Shows queue state, model version, training runs, candidate comparison, and processed runs. |

Each complete five-second window contains the required valid PIDs. The model predicts MAF (g/s) from RPM, speed, throttle, coolant and intake temperatures. Engine load is excluded because some ECUs derive it from airflow. A deviation requires three consecutive high-residual windows, about 15 seconds. A threshold is calibrated on the training runs. These windows are asynchronous PID polls, not true simultaneous ECU snapshots. Missing windows cannot be silently filled with zero.

The **last whole recording day** is held out for model comparison. We report MAF mean absolute error, alerts per scored hour, and a software perturbation check. The perturbation check does **not** measure real fault-detection accuracy. After selection, the chosen model is fitted on all accepted baseline runs and frozen. Future uploads are scored against it. No automatic retraining occurs after each upload, since that could teach a developing fault as normal.

## Kaggle source and reproducibility

The public candidate uses Cephas Barreto's [OBD-II datasets on Kaggle](https://www.kaggle.com/datasets/cephasax/obdii-ds3), specifically `dailyRoutes.csv` from the [author's public source repository](https://github.com/cephasax/OBDdatasets/tree/master/masterDegreeResearch). This file is semicolon-separated, uses decimal commas, and has many missing fields. Only rows with all six raw model signals were used. `car11` (Toyota Corolla; 7,288 usable rows) and `car12` (Nissan Versa; 1,678 usable rows) were selected for the public prior. The dataset's fuel-type column is blank for both, so we do not assert a verified fuel type. Raw public data is not committed. The trained prior and source SHA-256 are in `public_prior.json`.

Recreate the comparison from exported phone recordings:

```powershell
python -m ml.pipeline local --csv-dir D:\path\to\recordings --kaggle-csv D:\path\to\OBDdatasets\masterDegreeResearch\dailyRoutes.csv --out ml/output/comparison.json
```

The pipeline was run on eight supplied Yaris recordings (5 hours 30 minutes). On the held-out November 14 recordings (883 complete windows), the Yaris-only ridge model had 1.748 g/s MAF mean absolute error, the regime model 3.731 g/s, and the Kaggle-prior ridge model 1.893 g/s. All three had zero persistent alerts in this **unlabelled** holdout. The Yaris-only ridge model was selected. This is a result about normal-run prediction, not diagnostic sensitivity or proof of broad vehicle support.

## Cloud setup and processing

1. Apply `supabase/migrations/20261115000000_ml_pipeline.sql` to the existing project. Its backfill queues all previously completed uploads. It does not alter saved recordings.
2. Add GitHub Actions secrets `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`. The service-role key must stay in GitHub Actions secrets; never put it in Flutter assets, Dart source, or the mobile `.env`.
3. A push to this feature branch runs the worker when both secrets are available. The 15-minute automatic schedule starts after the workflow is merged into the repository's default branch. `workflow_dispatch` is also available once the workflow exists on the default branch.
4. In a debug build, open **Settings → Model diagnostics** and refresh to see queued, running, completed, or failed jobs and their results.

On each newly completed upload, the database trigger immediately creates a job. The scheduled worker processes it within roughly 15 minutes, subject to GitHub scheduling delay. The worker uses the Supabase service role only on the server and checks chunk order, SHA-256, sizes, and final sample count. A failed job retains its error for investigation. `ml_models` and `ml_run_results` are owner-readable under RLS and client-write-protected.

The model is created once per owner and vehicle using all completed runs available at bootstrap. Runs used for training are marked `baseline`; later uploads are `scored`. If there are fewer than 100 usable windows, the run is marked `insufficient_data` and another upload can establish the first model. A future retraining command should require reviewed healthy runs, new versioning, and an explicit evaluation gate.

## Claim and limits

> AutoPulseAI establishes a vehicle-specific normal OBD-II baseline and flags sustained airflow deviations under comparable operating conditions. A public OBD dataset was tested as a starting prior; the held-out Yaris data favoured the Yaris-only model. ECU trouble codes are separate diagnostic evidence. We have validated the baseline workflow on one Yaris and do not claim fault classification or deployment accuracy on other cars.

At present, one held-out day and no confirmed fault labels cannot establish fault precision or recall. More days, varied driving conditions, and ideally a second vehicle with compatible PIDs are needed for transfer claims. Even if another car is unavailable, public cross-vehicle experiments must remain separate from on-car validation.
