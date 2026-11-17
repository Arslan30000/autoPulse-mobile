"""Causal recording replay and annotation material; no labels or accuracy invented."""
import argparse
import csv
import hashlib
import json
from collections import Counter
from datetime import timedelta
from pathlib import Path
from .features import FEATURES, FeatureBuffer, Sample
from .rules import Stabilizer


def read_sessions(directory):
    sessions = {}
    for path in sorted(Path(directory).glob("*.csv")):
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        if not rows:
            continue
        required = {"session_id", "pid", "value", "quality", "received_at_utc"}
        if not required.issubset(rows[0]):
            raise ValueError(f"{path.name}: not a phone recording export")
        for row in rows:
            sessions.setdefault(row["session_id"], []).append(Sample.from_row(row))
    if not sessions:
        raise ValueError("No recording CSV files found")
    for key, samples in sessions.items():
        sessions[key] = sorted(samples, key=lambda s: s.at)
    return sessions


def timeline(samples, observer=None, predictor=None):
    """Evaluate 1 Hz, observing only samples already received at that instant."""
    buffer, state = FeatureBuffer(), Stabilizer()
    at, end, cursor = samples[0].at, samples[-1].at, 0
    while True:
        notices = []
        attempts = []
        while cursor < len(samples) and samples[cursor].at <= at:
            sample = samples[cursor]
            attempts.append(sample)
            buffer.add(sample)
            notice = state.step(buffer, sample.at, predictor=predictor)
            if notice:
                notices.append(notice)
            cursor += 1
        state.step(buffer, at, fresh=False, predictor=predictor)
        if observer:
            observer(at, attempts, buffer.extract(at), state)
        yield at, buffer.extract(at), state.state, state.demand, notices
        if at == end:
            break
        at = min(at + timedelta(seconds=1), end)


def run(directory, output, model_path=None):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    model = json.loads(Path(model_path).read_text(encoding="utf-8")) if model_path else None
    if model:
        from .train import predict
        predictor = lambda values, previous: predict(model, values, previous)
    else:
        predictor = None
    report = {"evaluator": model["version"] if model else "rules-v1", "classification_accuracy": None,
              "warning": "Unlabelled replay: availability and state counts are NOT accuracy.", "sessions": []}
    for session_id, samples in read_sessions(directory).items():
        # IDs never become output paths directly.
        stem = hashlib.sha256(session_id.encode()).hexdigest()[:16]
        counts, complete, banners, total = Counter(), 0, 0, 0
        with (output/f"{stem}-timeline.csv").open("w", newline="", encoding="utf-8") as handle, (output/f"{stem}-replay.jsonl").open("w", encoding="utf-8") as tape:
            def observe(at, attempts, features, state):
                tape.write(json.dumps({"at": at.isoformat(), "attempts": [
                    {"pid": s.pid, "at": s.at.isoformat(), "value": s.value, "quality": s.quality}
                    for s in attempts], "features": features, "state": state.state, "high_demand": state.demand}, allow_nan=False)+"\n")
            writer = csv.writer(handle)
            writer.writerow(["session_id", "at", "state_estimate", "high_demand", "notice", *FEATURES])
            for at, values, state, demand, notices in timeline(samples, observer=observe, predictor=predictor):
                total += 1
                complete += values is not None
                banners += len(notices)
                counts[state] += 1
                writer.writerow([session_id, at.isoformat(), state, demand, "|".join(notices), *(values or [""]*len(FEATURES))])
        report["sessions"].append({"id": session_id, "samples": len(samples),
                                   "span_seconds": (samples[-1].at-samples[0].at).total_seconds(),
                                   "evaluation_ticks": total, "feature_ticks": complete, "availability": complete/total,
                                   "context_ticks": counts, "significant_notices": banners})
    (output/"replay-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv-dir", required=True)
    parser.add_argument("--out", default="ml/output/driving_context/replay")
    parser.add_argument("--model", help="Optional experimental/reviewed JSON for inference replay")
    args = parser.parse_args()
    run(args.csv_dir, args.out, model_path=args.model)
