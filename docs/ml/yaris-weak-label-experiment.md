# Yaris context bootstrap: existing data labelled and models trained

17 November 2026. Feature branch: `feature/driving-context-runtime`.
This supersedes the initial rules-only status in `driving-context-validation.md`.
The implementation is published separately for review; merging into `main` is
a separate decision.

Validation: static analysis and Dart formatting passed; **251 Flutter tests**
passed (one opt-in live-backend audit skipped), and **12 Python tests** passed.
The actual trained-model Dart replay matched Python at all **9,737 evaluation
ticks**, covering **41,866 PID attempts** across all three recordings. This is
software agreement, separate from the weak-label metrics below. Real phone/car
accuracy has not yet been tested for this model.

The updated signed debug APK is saved at
`D:\FYP\artifacts\driving-context\weak-v1\debug.apk`; SHA-256/build provenance is
in `build-info.json` beside it. Its packaged model content was verified against
the exact tested source artifact, and experimental opt-in was checked. The
earlier `artifacts/driving-context/debug.apk` is the older rules-only build.

## What was done now

Used the three existing local Yaris CSVs, unchanged: 41,866 PID attempts across
about 2.70 hours on 10-11 November. Generated reproducible, conservative
telemetry-derived labels, trained three real classifiers, compared them on the
later recording day, and packaged a 40-tree forest for offline Flutter inference.
No new recording day, Kaggle data, invented fault, or synthetic training sample
was required for this experiment. Synthetic vectors are used only for software
prediction-parity tests.

This is **weak supervision**: operational labels inferred from measured signals.
They are not independently observed ground truth. The generated CSVs explicitly
say `reviewed=false`, `confidence=provisional`, and
`label_source=telemetry-weak-v1`. The original strict reviewed-label trainer still
rejects them. A separate explicit bootstrap command handles this experiment.

## Labelling policy and support

`ml/driving_context/weak_labels.py` contains the versioned policy. Stationary
speed with running RPM supports idling; stationary near-zero RPM supports engine
off. Received-time speed slopes support acceleration/deceleration. Steady movement
with high reported ECU load supports heavy load, not an independently confirmed
incline. Lower/higher steady speed bands support estimated cruising regimes.

Labels close to boundaries, unsupported/invalid/stale inputs, short runs and
transitions remain uncertain. Proposed regimes must persist for eight seconds;
the first five seconds and final second are excluded from model-fitting windows.
This intentionally trades label quantity for conservative examples. All future
features remain excluded: online features use only the causal five-second history.

| State | Retained windows | Earlier-day training labels | Later-day test labels |
| --- | ---: | ---: | ---: |
| Engine off | 626 | 592 | 34 |
| Idling | 631 | 305 | 326 |
| City cruising | 97 | 88 | 9 |
| Accelerating | 391 | 228 | 163 |
| Decelerating | 53 | 28 | 25 |
| Heavy load | 59 | 53 | 6 |
| Highway cruising | 0 | 0 | 0 |
| Strong acceleration | 0 | 0 | 0 |
| **Retained total** | **1,857** | **1,294** | **563** |

7,880 of 9,737 evaluation ticks remain uncertain/excluded; their measurements
are preserved. The files contain higher-speed driving, but only 81 ticks meet the
strict proposed highway criteria and none form an eight-second run. Maximum
five-second speed slope is about 1.43 m/s², below the strong-acceleration threshold
of 1.5 m/s². These classes were not fabricated or claimed as learned.

The forest itself is fitted on **397 moving windows**: 88 city-cruise, 228
acceleration, 28 deceleration and 53 heavy-load examples. Idle and engine-off
remain direct physical checks; their 897 earlier-day labels are not counted as
forest-fitting examples. Overlapping windows are correlated, so these counts do
not represent that many independent events. There are 137 provisional annotation
intervals across the complete dataset, including stationary intervals.

## Models, split and results

Trained a depth-4 decision tree, a 20-tree depth-4 Random Forest and a 40-tree
depth-6 Random Forest using balanced class weights, min leaf size 5 and seed 17.
The 40-tree candidate was chosen **before** examining held-out scores; no
hyperparameter tuning was performed on the only test day.

Both November 10 recordings were training inputs; the November 11 recording was
held out. Whole trips remain separate, including feature histories. No random
shuffle of neighboring windows is used, and the packaged model has not been
refitted on the held-out trip. File hashes, label hashes, model settings and exact
session membership are stored in the artifact/report provenance.

On the 563 retained held-out windows, the final hybrid achieved 1.0 macro-F1 over
the classes present **against telemetry-derived labels**. Raw forest votes exceed
the 0.60 threshold on 201 of 203 retained moving test windows (99.01%). The
hybrid includes rules for stationary states, unsupported classes and low votes.
These scores measure agreement with the labelling policy. They do **not** establish
independent context accuracy, false-alert rate, mechanical diagnosis or new-car
performance. Nine city-cruise and six heavy-load test windows are particularly
small support. No trained-model improvement over the rules is claimed.

## What the app now runs

The packaged artifact is
`assets/ml/driving_context/context-weak-yaris-v1-forest-40-depth6.json`.
`assets/ml/registry.json` explicitly selects it and sets
`allow_experimental_driving_context=true`. Startup loads it into the same existing
OBD sample pipeline; no extra Bluetooth polling or server inference call is added.

The card says **Live estimate · Experimental model + rules**. The actual trained
forest runs on live features for its learned moving states. Physical checks handle
idle/engine-off. Highway cruising, strong acceleration and low forest votes use
explicit rule fallbacks. Missing/stale data still shows waiting. There is no
calibrated-confidence percentage, hill confirmation or change to the mock health
score. Existing notification persistence, touch-through and DTC priority remain.

The production loader still rejects synthetic test artifacts and weak models
without explicit opt-in. An independently reviewed model can use the existing
reviewed-label path later without rebuilding the architecture.

## Files you can inspect

All generated training data/experiments stay under ignored
`ml/output/driving_context/bootstrap/`:

- `labelled-windows.csv`: each received-time window, features, proposed label,
  retained training label and explanation.
- `provisional-annotations.csv`: 137 sidecar intervals for review/correction.
- `label-summary.json`: thresholds, retained counts and exclusions.
- `bootstrap-report.json`: all three candidates, provenance and held-out comparisons.
- `context-weak-yaris-v1-*.json`: the three fitted model artifacts.
- `selected-model-parity.json`: synthetic feature probes and Python reference votes.
- `model-replay/`: the packaged model's causal replay across all source readings.
- `review/index.html` and three PNGs: speed, RPM, load, speed-slope and label plots.

Only the selected model and controlled parity probes are packaged/tracked as
runtime/test assets; raw trip exports and generated training tables are not added
to Git. `ml/README.md` indexes model tasks; the existing server MAF model remains
separate.

## Continue with tomorrow's data

Keep the original CSVs, add new exports, then rerun bootstrap into a new output
folder with a new version, e.g. `--version context-weak-yaris-v2 --out
ml/output/driving_context/bootstrap-v2`. Review the proposed intervals and add
independent event notes for ambiguous/rare regimes. The same labelling, features,
training, export and Flutter inference tools are reused. This is continuation of
the current experiment, not starting from scratch. Preserve future untouched test
trips; a repeatedly inspected holdout cannot remain an independent final test.

Weak-supervision background: [Snorkel authors' paper](https://arxiv.org/abs/1711.10160).
This project uses simple deterministic labelling functions; it does not install
Snorkel or claim its probabilistic denoising. Split rationale:
[scikit-learn cross-validation guidance](https://scikit-learn.org/1.8/modules/cross_validation.html).
