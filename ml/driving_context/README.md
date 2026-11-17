# Driving context (offline phone inference)

Status: **experimental Yaris-trained Random Forest + rules**, packaged for live
offline inference. Labels were generated conservatively from existing telemetry
and remain explicitly unreviewed. Independent context accuracy is unknown.
Existing `ml/model.py` predicts MAF and is a separate model.

The first experiment has already been run; see
[`docs/ml/yaris-weak-label-experiment.md`](../../docs/ml/yaris-weak-label-experiment.md).
The strict reviewed-label workflow below remains available alongside an explicitly
experimental bootstrap workflow; neither tomorrow's data nor a fresh project is
required to run the first experiment.

| Location | Purpose |
| --- | --- |
| `lib/services/driving_context/` | Causal features, rules, forest interpreter, model loader, state controller |
| `lib/models/driving_context.dart` | States and notifications |
| `lib/core/widgets/driving_context_card.dart` | Health-page live card; Provider subscribes to the app-scoped controller |
| `lib/core/widgets/context_change_banner.dart` | Touch-through 3.5-second notification |
| `ml/driving_context/` | Python feature parity, replay, reviewed-label training and export |
| `ml/driving_context/weak_labels.py` | Conservative, versioned telemetry labelling; never marks labels reviewed |
| `ml/driving_context/bootstrap.py` | Two-day experimental model training using existing recordings |
| `ml/driving_context/review.py` | Signal/label review plots for existing recordings |
| `ml/tests/test_driving_context.py` | Offline tooling and parity checks |
| `test/driving_context/` | Flutter logic, integration, UI and notification tests |
| `assets/ml/registry.json` | Explicit model selection and experimental opt-in; null means rules |
| `assets/ml/driving_context/` | Versioned runtime artifacts with honest provenance, never raw data |
| `ml/output/driving_context/` | Ignored replay, training and experiment outputs |
| `docs/ml/` | Curated validation results and release limitations |

Run these commands from the repository root. Raw CSVs stay in the local `data/`
folder, unchanged. Never add telemetry exports or secrets to Git without review.

```powershell
# Label existing recordings, train three candidates, keep the latest day held out.
python -m ml.driving_context.bootstrap --csv-dir data/Toyota_Yaris_Data --out ml/output/driving_context/bootstrap

# Optional visual review (requires matplotlib).
python -m ml.driving_context.review --labelled-windows ml/output/driving_context/bootstrap/labelled-windows.csv --out ml/output/driving_context/bootstrap/review

# No dependencies or Bluetooth required; writes estimates, not truth labels.
python -m ml.driving_context.replay --csv-dir data/Toyota_Yaris_Data --out ml/output/driving_context/replay

# Copy the header, then independently annotate continuous reviewed intervals.
Copy-Item ml/driving_context/annotations/template.csv ml/output/driving_context/annotations.csv

# Only needed when reviewed labels and three or more recording days exist.
python -m pip install -r ml/driving_context/requirements.txt
python -m ml.driving_context.train --csv-dir data/Toyota_Yaris_Data --annotations ml/output/driving_context/annotations.csv --out ml/output/driving_context/training

python -m unittest discover -s ml/tests -v
flutter test test/driving_context

# Local real-recording agreement checks (no raw CSVs enter CI/Git).
flutter test test/driving_context/recorded_replay_test.dart --dart-define=CONTEXT_REPLAY_DIR=ml/output/driving_context/replay

# Replay the selected trained model through both Python and Dart.
python -m ml.driving_context.replay --csv-dir data/Toyota_Yaris_Data --model assets/ml/driving_context/context-weak-yaris-v1-forest-40-depth6.json --out ml/output/driving_context/bootstrap/model-replay
flutter test test/driving_context/recorded_replay_test.dart --dart-define=CONTEXT_REPLAY_DIR=ml/output/driving_context/bootstrap/model-replay --dart-define=CONTEXT_REPLAY_MODEL=assets/ml/driving_context/context-weak-yaris-v1-forest-40-depth6.json
```

Bootstrap writes `labelled-windows.csv`, `provisional-annotations.csv`, all three
candidate model JSONs, their comparison/provenance report, and reference votes.
It never sets `reviewed=true`. Ambiguous/short/transition intervals stay uncertain.
The 40-tree depth-6 forest is selected in advance, not chosen by tuning on the
only held-out day. Reported metrics are agreement with weak labels, not independent
driving accuracy. Replaying that same label policy in train/test does not establish
the policy's correctness. The app deliberately uses physical-rule fallbacks for
stationary states, unseen classes and weak model votes below 0.60; the card says
**Experimental model + rules**. Synthetic test models remain prohibited.

For the next collection, add the new raw CSVs without changing originals, review
the proposed labels/uncertain intervals, and rerun into a new experiment folder
with `--version context-weak-yaris-v2 --out ml/output/driving_context/bootstrap-v2`.
Do not silently overwrite a previously packaged artifact or reuse a repeatedly
inspected test day as untouched evidence. Model fitting continues from the same
tools and feature schema; it does not start from scratch. Independently reviewed
labels and additional days support the stricter workflow described next.

Annotation times must include UTC offset. `state` uses Dart enum names:
`engineOff`, `idling`, `cityCruising`, `highwayCruising`, `accelerating`,
`aggressiveAcceleration` (displayed as **Strong Acceleration**), `decelerating`,
`heavyLoad`, or `uncertain`. Include a named `reviewer`, `reviewed=true`, and
`confidence=high` or `medium`. Mark uncertain transitions explicitly. An interval
is half-open `[start,end)`; the whole five-second feature window must fit inside
it. `secondary_flags` and notes preserve load/AC/route observations for review;
they are not automatically learned labels. Never treat generated state estimates
as independent truth. Training refuses missing labels, overlapping annotations,
unknown recordings and fewer than three labelled days. Session start in UTC
assigns whole trips to days; the last day is untouched testing, the previous day
tuning, and all earlier days training. No adjacent-window random split is used.

Training compares rules, a depth-4 tree, and 20/40-tree depth-4/6 forests on the
tuning day. The winner is fitted on pre-test days only, then tested once. If rules
win, no trained artifact is emitted. Reports include support, coverage, confusion
matrix and per-class scores. Missing classes, a small number of days, and event
quality still require independent review; window scores do not approve a release.
This tooling does not claim new-car accuracy or manufacture labels to get a score.

For an independently reviewed model: inspect `training-report.json`, event-level replay results,
all important class support, and real-phone behavior. Copy the selected versioned
JSON into `assets/ml/driving_context/`, set `driving_context` in the registry to
`assets/ml/driving_context/<version>.json`, and rebuild. Startup loads that artifact
automatically; all decisions then run locally, including offline. The loader
rejects incompatible schemas, invalid tree bounds/classes, and unreviewed models
unless the artifact explicitly declares the supported weak-label provenance and
the registry explicitly enables experimental context models.
A bad/missing model falls back to visibly provisional rules. The asset loader also
refuses explicitly synthetic/test-only artifacts. `parity.json` records
Python reference predictions for the exported artifact; verify Dart parity before
shipping a new artifact. No raw training file, pickle or service key enters the APK.

Context uses RPM, speed, load, throttle and a causal speed slope (m/s²). It does
not add PID requests or require MAP, MAF or fuel trims. RPM/speed expire after 3s,
load/throttle after 5s. Failed attempts invalidate previous values; derivative
history cannot bridge failed readings or >3s gaps. No zeros fill missing data.
At least three speed readings spanning 1.5s are needed. The stabilizer requires
new speed evidence for 2s, or 5s plus two load updates for high demand. Thresholds
have hysteresis; significant notices have a 25s cooldown. Initial/recovered states
are quiet. Session/account/vehicle changes clear history; background pause disconnects.
These are version-one engineering thresholds, not learned or calibrated values.

High load is a secondary modifier even during acceleration or deceleration. It
does not prove an incline. City/highway names are speed-band estimates. Stationary
revving is not acceleration, the model cannot alter the health score, and DTCs
retain notification priority. The existing health score/system tiles remain sample
data. Model votes are not shown as calibrated confidence percentages.

Reference: [scikit-learn 1.8 RandomForestClassifier](https://scikit-learn.org/1.8/modules/generated/sklearn.ensemble.RandomForestClassifier.html).
The portable interpreter mirrors float32 split inputs and averaged leaf votes.
