"""Train only from independently reviewed sidecar labels. No automatic deployment."""
import argparse
import csv
from datetime import timedelta, datetime, timezone
import hashlib
import json
from pathlib import Path
import struct

from .features import FEATURES, timestamp
from .replay import read_sessions, timeline
from .rules import evaluate

MOVING_CLASSES = ["cityCruising", "highwayCruising", "accelerating",
                  "aggressiveAcceleration", "decelerating", "heavyLoad"]
CLASSES = ["engineOff", "idling", *MOVING_CLASSES]


def annotations(path):
    result = {}
    with Path(path).open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            if row["reviewed"].lower() != "true" or row["state"] == "uncertain":
                continue
            if row["state"] not in CLASSES or not row["reviewer"].strip():
                raise ValueError("Reviewed annotations require a known state and named reviewer")
            if row["confidence"] not in ("high", "medium"):
                continue
            start, end = timestamp(row["start_utc"]), timestamp(row["end_utc"])
            if start >= end:
                raise ValueError("Annotation start must precede end")
            result.setdefault(row["session_id"], []).append((start, end, row["state"]))
    if not result:
        raise ValueError("No reviewed context labels. Annotate recordings before training; PID labels are not context labels.")
    for intervals in result.values():
        intervals.sort()
        if any(b[0] < a[1] for a, b in zip(intervals, intervals[1:])):
            raise ValueError("Overlapping annotations are ambiguous")
    return result


def examples(sessions, labels):
    result = []
    for session_id, samples in sessions.items():
        # Whole trips belong to one UTC start day, including trips across midnight.
        day = samples[0].at.astimezone(timezone.utc).date().isoformat()
        for at, values, _, _, _ in timeline(samples):
            if values is None:
                continue
            matches = [state for start, end, state in labels.get(session_id, [])
                       if start <= at-timedelta(seconds=5) and at < end]
            if matches:
                result.append({"session_id": session_id, "day": day, "at": at,
                               "values": values, "state": matches[0]})
    if not result:
        raise ValueError("No complete causal windows fall inside reviewed annotation intervals")
    return result


def temporal_split(rows):
    days = sorted({r["day"] for r in rows})
    if len(days) < 3:
        raise ValueError("Need at least three labelled recording days: training, tuning and untouched testing")
    training = [r for r in rows if r["day"] < days[-2]]
    tuning = [r for r in rows if r["day"] == days[-2]]
    testing = [r for r in rows if r["day"] == days[-1]]
    return training, tuning, testing


def export_forest(estimator, *, version, provenance, reviewed_labels=True, label_source="reviewed"):
    trees = []
    estimators = getattr(estimator, "estimators_", [estimator])
    if not 1 <= len(estimators) <= 50:
        raise ValueError("Runtime supports at most 50 trees")
    for tree in estimators:
        t = tree.tree_
        if t.max_depth > 6 or t.node_count > 127:
            raise ValueError("Runtime supports depth <= 6")
        nodes = []
        for i in range(t.node_count):
            if t.children_left[i] == -1:
                values = t.value[i][0]
                total = float(sum(values))
                nodes.append({"votes": [float(x/total) for x in values]})
            else:
                nodes.append({"feature": int(t.feature[i]), "threshold": float(t.threshold[i]),
                              "left": int(t.children_left[i]), "right": int(t.children_right[i])})
        trees.append(nodes)
    return {"schema_version": 1, "task": "driving_context", "version": version,
            "reviewed_labels": reviewed_labels, "label_source": label_source,
            "experimental": not reviewed_labels, "features": FEATURES,
            "classes": list(estimator.classes_), "trees": trees,
            "calibration": "uncalibrated votes; abstain below 0.60",
            "provenance": provenance}


def votes(model, values):
    # Match sklearn's float32 split inputs, then sum in double precision.
    values = [struct.unpack("f", struct.pack("f", float(x)))[0] for x in values]
    result = [0.0]*len(model["classes"])
    for nodes in model["trees"]:
        index = 0
        while "votes" not in nodes[index]:
            node = nodes[index]
            index = node["left"] if values[node["feature"]] <= node["threshold"] else node["right"]
        for j, value in enumerate(nodes[index]["votes"]):
            result[j] += value/len(model["trees"])
    return result


def predict(model, values, previous="reading"):
    rule = evaluate(values, previous)
    if values[0] <= 2 or values[1] < 200:
        return rule
    # Never pretend an unobserved class was learned from this vehicle's data.
    if rule not in model["classes"]:
        return rule
    distribution = votes(model, values)
    best = max(range(len(distribution)), key=distribution.__getitem__)
    if distribution[best] < .6:
        return rule if model.get("experimental") else "insufficient"
    state = model["classes"][best]
    if state == "aggressiveAcceleration" and (values[4] < 1.2 or values[2] < 60 or values[3] < 25):
        return rule
    if state == "decelerating" and values[4] > -.35:
        return rule
    if state == "heavyLoad" and values[2] < 72:
        return rule
    return state


def metrics(rows, predictor):
    from sklearn.metrics import classification_report, confusion_matrix
    truth = [r["state"] for r in rows]
    predicted = [predictor(r["values"]) for r in rows]
    labels = [*CLASSES, "insufficient"]
    report = classification_report(truth, predicted, labels=labels, output_dict=True, zero_division=0)
    # Abstention contributes to false negatives; don't score only easy windows.
    present = sorted(set(truth))
    return {"macro_f1_present_classes": sum(report[s]["f1-score"] for s in present)/len(present),
            "coverage": sum(p != "insufficient" for p in predicted)/len(predicted),
            "classes": report, "confusion_labels": labels,
            "confusion_matrix": confusion_matrix(truth, predicted, labels=labels).tolist(),
            "windows": len(rows)}


def run(csv_dir, label_path, out):
    # Validate label availability before importing optional ML dependencies.
    labels = annotations(label_path)
    sessions = read_sessions(csv_dir)
    unknown = set(labels)-set(sessions)
    if unknown:
        raise ValueError(f"Annotations reference unavailable sessions: {sorted(unknown)}")
    rows = examples(sessions, labels)
    training, tuning, testing = temporal_split(rows)
    import sklearn
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.tree import DecisionTreeClassifier
    train_moving = [r for r in training if r["state"] in MOVING_CLASSES]
    if len(train_moving) < 100 or len({r["state"] for r in train_moving}) < 2:
        raise ValueError("Need >=100 reviewed moving windows across >=2 classes in training days")
    candidates = {
        "tree-depth4": DecisionTreeClassifier(max_depth=4, min_samples_leaf=5, class_weight="balanced", random_state=17),
        "forest-20-depth4": RandomForestClassifier(n_estimators=20, max_depth=4, min_samples_leaf=5, class_weight="balanced", random_state=17, n_jobs=1),
        "forest-40-depth6": RandomForestClassifier(n_estimators=40, max_depth=6, min_samples_leaf=5, class_weight="balanced", random_state=17, n_jobs=1),
    }
    comparisons = {"rules-v1": metrics(tuning, evaluate)}
    for name, estimator in candidates.items():
        estimator.fit([r["values"] for r in train_moving], [r["state"] for r in train_moving])
        model = export_forest(estimator, version=name, provenance={})
        comparisons[name] = metrics(tuning, lambda x: predict(model, x))
    selected = max(comparisons, key=lambda name: comparisons[name]["macro_f1_present_classes"])
    provenance = {"created_at": datetime.now(timezone.utc).isoformat(), "sklearn_version": sklearn.__version__,
                  "annotation_sha256": hashlib.sha256(Path(label_path).read_bytes()).hexdigest(),
                  "sources": [{"file": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                              for p in sorted(Path(csv_dir).glob("*.csv"))],
                  "training_sessions": sorted({r["session_id"] for r in training+tuning}),
                  "test_sessions": sorted({r["session_id"] for r in testing}),
                  "test_day": testing[0]["day"], "selected_candidate": selected}
    report = {"provenance": provenance, "tuning_comparison": comparisons,
              "release_approved": False,
              "limitations": "Window metrics only. Event precision, false notices/hour, delay, on-phone replay and independent review still required."}
    output = Path(out)
    output.mkdir(parents=True, exist_ok=True)
    if selected == "rules-v1":
        report["test"] = metrics(testing, evaluate)
        report["artifact"] = None
    else:
        estimator = candidates[selected]
        all_moving = [r for r in training+tuning if r["state"] in MOVING_CLASSES]
        estimator.fit([r["values"] for r in all_moving], [r["state"] for r in all_moving])
        model = export_forest(estimator, version="context-"+datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"), provenance=provenance)
        report["test"] = metrics(testing, lambda x: predict(model, x))
        artifact = output/(model["version"]+".json")
        artifact.write_text(json.dumps(model, indent=2, allow_nan=False), encoding="utf-8")
        # Store cross-language reference predictions for the future accepted model.
        parity = [{"values": r["values"], "votes": votes(model, r["values"]),
                   "state": predict(model, r["values"])} for r in testing[:100]]
        (output/"parity.json").write_text(json.dumps(parity, indent=2), encoding="utf-8")
        report["artifact"] = artifact.name
    (output/"training-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv-dir", required=True)
    parser.add_argument("--annotations", required=True)
    parser.add_argument("--out", default="ml/output/driving_context/training")
    args = parser.parse_args()
    try:
        run(args.csv_dir, args.annotations, args.out)
    except ValueError as error:
        parser.exit(2, f"Training stopped: {error}\n")
