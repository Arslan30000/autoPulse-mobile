"""Label existing real recordings and train experimental models with weak supervision.

Unlike train.py, this is an explicitly provisional two-day experiment. It never
marks heuristic labels as reviewed. It never installs an artifact automatically.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import re
from pathlib import Path

from .features import FEATURES
from .replay import read_sessions
from .train import export_forest, metrics, predict, votes, MOVING_CLASSES, CLASSES
from .weak_labels import LABEL_SOURCE, POLICY, label_sessions, save_labels


def run(csv_dir, out, version="context-weak-yaris-v1"):
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", version):
        raise ValueError("Use a version containing only letters, digits, underscores and hyphens")
    import sklearn
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.tree import DecisionTreeClassifier
    output = Path(out)
    output.mkdir(parents=True, exist_ok=True)
    sessions = read_sessions(csv_dir)
    records, intervals = label_sessions(sessions)
    summary = save_labels(records, intervals, output)
    rows = [{"session_id": r["session_id"], "at": r["at"], "values": r["values"], "state": r["state"],
             "day": sessions[r["session_id"]][0].at.astimezone(timezone.utc).date().isoformat()}
            for r in records if r["state"] != "uncertain"]
    days = sorted({r["day"] for r in rows})
    if len(days) < 2:
        raise ValueError("Bootstrap needs at least two labelled recording days for an untouched later-day comparison")
    training = [r for r in rows if r["day"] < days[-1]]
    testing = [r for r in rows if r["day"] == days[-1]]
    moving = [r for r in training if r["state"] in MOVING_CLASSES]
    if len(moving) < 100 or len({r["state"] for r in moving}) < 2:
        raise ValueError("Insufficient stable moving examples to train a classifier")
    # Selection is fixed BEFORE inspecting held-out scores. Do not tune on the
    # only test day and then claim that same day is an independent final test.
    selected = "forest-40-depth6"
    candidates = {
        "tree-depth4": DecisionTreeClassifier(max_depth=4, min_samples_leaf=5, class_weight="balanced", random_state=17),
        "forest-20-depth4": RandomForestClassifier(n_estimators=20, max_depth=4, min_samples_leaf=5, class_weight="balanced", random_state=17, n_jobs=1),
        "forest-40-depth6": RandomForestClassifier(n_estimators=40, max_depth=6, min_samples_leaf=5, class_weight="balanced", random_state=17, n_jobs=1),
    }
    provenance = {"created_at": datetime.now(timezone.utc).isoformat(), "sklearn_version": sklearn.__version__,
                  "label_source": LABEL_SOURCE, "label_policy": POLICY, "reviewed": False,
                  "label_sha256": hashlib.sha256((output/"provisional-annotations.csv").read_bytes()).hexdigest(),
                  "source_files": [{"file": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                                   for p in sorted(Path(csv_dir).glob("*.csv"))],
                  "training_sessions": sorted({r["session_id"] for r in training}),
                  "test_sessions": sorted({r["session_id"] for r in testing}),
                  "training_days": days[:-1], "test_day": days[-1],
                  "selection_policy": "forest-40-depth6 fixed before test evaluation; no hyperparameter tuning",
                  "independent_context_accuracy": None,
                  "forest_training_windows": len(moving),
                  "unobserved_moving_classes": sorted(set(MOVING_CLASSES)-{r["state"] for r in moving}),
                  "stationary_policy": "Engine-off/idling use physical rules; forest learns moving states"}
    provenance["runtime_policy"] = "Experimental model + rules: physical stationary guards, unseen-class and votes<0.60 rule fallback"
    report = {"status": "experimental_weak_supervision", "release_approved": False,
              "label_summary": summary, "provenance": provenance,
              "training_windows": len(training), "test_windows": len(testing),
              "forest_training_windows": len(moving),
              "stationary_training_labels": len(training)-len(moving),
              "training_counts": Counter(r["state"] for r in training),
              "test_counts": Counter(r["state"] for r in testing),
              "metric_interpretation": "Agreement with telemetry-derived labels on held-out recordings, NOT independently measured driving accuracy.",
              "models": {}, "selected": selected}
    models = {}
    for name, estimator in candidates.items():
        estimator.fit([r["values"] for r in moving], [r["state"] for r in moving])
        model = export_forest(estimator, version=version+"-"+name,
                              provenance=provenance, reviewed_labels=False, label_source=LABEL_SOURCE)
        model_path = output/(model["version"]+".json")
        model_path.write_text(json.dumps(model, indent=2, allow_nan=False), encoding="utf-8")
        test_moving = [r for r in testing if r["state"] in MOVING_CLASSES]
        vote_coverage = sum(max(votes(model, r["values"])) >= .6 for r in test_moving)/len(test_moving) if test_moving else None
        report["models"][name] = {"artifact": model_path.name, "bytes": model_path.stat().st_size,
                                 "held_out_moving_windows": len(test_moving), "raw_forest_vote_coverage": vote_coverage,
                                 "held_out_weak_label_agreement": metrics(testing, lambda x: predict(model, x))}
        models[name] = model
    model = models[selected]
    report["selected_artifact"] = report["models"][selected]["artifact"]
    # Build parity references using controlled feature vectors, NOT raw trip data.
    vectors = [[speed, rpm, load, throttle, accel, 5, 200, 3]
               for speed in (0, 20, 60, 100, 125) for rpm in (0, 1600)
               for load, throttle in ((40, 20), (90, 60)) for accel in (-1, 0, .7, 2)]
    parity = {"model_version": model["version"], "label_source": LABEL_SOURCE,
              "features": FEATURES, "reference_inputs": "Synthetic feature probes for a model trained on real Yaris recordings",
              "predictions": [{"values": x, "votes": votes(model, x), "state": predict(model, x)} for x in vectors]}
    (output/"selected-model-parity.json").write_text(json.dumps(parity, indent=2), encoding="utf-8")
    # No classification value is labelled independent accuracy or confidence.
    (output/"bootstrap-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output), "labels": summary["training_state_counts"],
                      "training_windows": len(training), "test_windows": len(testing),
                      "forest_training_windows": len(moving),
                      "selected": selected, "artifact": report["selected_artifact"],
                      "agreement_only": {name: r["held_out_weak_label_agreement"]["macro_f1_present_classes"]
                                         for name, r in report["models"].items()},
                      "independent_accuracy": None}, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv-dir", required=True)
    parser.add_argument("--out", default="ml/output/driving_context/bootstrap")
    parser.add_argument("--version", default="context-weak-yaris-v1", help="Use a new version for each subsequent dataset/model release")
    args = parser.parse_args()
    try:
        run(args.csv_dir, args.out, args.version)
    except ValueError as error:
        parser.exit(2, f"Experimental training stopped: {error}\n")
