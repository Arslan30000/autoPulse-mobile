"""Local context-aware sensor diagnostics. Raw recordings are read-only."""
import argparse
import csv
import hashlib
import json
import math
import re
from collections import Counter, defaultdict
from dataclasses import replace
from datetime import timedelta
from pathlib import Path
from statistics import median
from tempfile import NamedTemporaryFile
from uuid import UUID

from ml.driving_context.features import timestamp
from ml.driving_context.replay import read_sessions, timeline
from ml.model import _solve

CONTEXT_MODEL = "assets/ml/driving_context/context-weak-yaris-v1-forest-40-depth6.json"
# name, unit, minimum residual, persistence windows, decoded range
SIGNALS = {
    16: ("Mass airflow", "g/s", 1.0, 3, (0, 655.35)),
    5: ("Coolant temperature", "°C", 4.0, 6, (-40, 215)),
    15: ("Intake temperature", "°C", 5.0, 6, (-40, 215)),
    6: ("Short fuel trim B1", "%", 5.0, 4, (-100, 99.22)),
    7: ("Long fuel trim B1", "%", 4.0, 6, (-100, 99.22)),
}
CHECKS = {
    16: "Inspect the intake duct, air filter and MAF connector. Compare with fuel trims and available ECU codes.",
    5: "Review the warm-up trace and consult the service manual for cooling-system checks.",
    15: "Compare moving readings with stationary heat soak. Inspect the intake temperature connector if the deviation recurs.",
    6: "Compare both fuel trims at warm idle and steady cruise. Review available codes before inspecting intake and fuel delivery.",
    7: "Compare both fuel trims at warm idle and steady cruise. Review available codes before inspecting intake and fuel delivery.",
}
MIN_WINDOWS = 30
STABLE = {"idling", "cityCruising", "highwayCruising", "heavyLoad", "accelerating",
          "aggressiveAcceleration", "decelerating"}


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def save(path, obj):
    file = Path(path)
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(json.dumps(obj, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
    print(file)


def digest(samples):
    payload = [(s.pid, s.at.isoformat(), s.value, s.quality) for s in samples]
    return hashlib.sha256(json.dumps(payload).encode()).hexdigest()


def windows(samples, context_model):
    from ml.driving_context.train import predict

    latest = {}
    origin = samples[0].at
    last_bucket = -1

    def observe(at, attempts, features, state):
        for sample in attempts:
            latest[sample.pid] = sample

    predictor = lambda values, previous: predict(context_model, values, previous)
    for at, features, state, demand, _ in timeline(samples, observer=observe, predictor=predictor):
        elapsed = (at - origin).total_seconds()
        bucket = int(elapsed // 5)
        if bucket == last_bucket:
            continue
        last_bucket = bucket
        available = {}
        quality = {}
        for pid, (_, _, _, _, bounds) in SIGNALS.items():
            sample = latest.get(pid)
            reason = "missing"
            if sample:
                reason = sample.quality
                if (at - sample.at).total_seconds() >= 5:
                    reason = "stale"
                elif reason == "valid":
                    if sample.value is None or not bounds[0] <= sample.value <= bounds[1]:
                        reason = "invalid"
                    else:
                        available[pid] = sample.value
            quality[pid] = reason
        if features is None or state not in STABLE:
            yield bucket, at, None, [], available, quality
            continue
        speed, rpm, _, throttle = features[:4]
        # Restrict thermal comparisons by time since recording began and airflow demand.
        phase = "initial" if elapsed < 600 else "later"
        group = f"{state}:{'demand' if demand else 'ordinary'}"
        x = [1., rpm / 3000, speed / 120, throttle / 100, min(elapsed, 600) / 600]
        yield bucket, at, group + ":" + phase, x, available, quality


def key_for(context, pid, method):
    if method == "pooled":
        return [str(pid), "*"]
    return [str(pid), context if pid in (5, 15, 6, 7) else context.rsplit(":", 1)[0]]


def observations(trips, method):
    groups = defaultdict(list)
    for trip in trips:
        for _, _, context, x, values, _ in trip:
            if context:
                for pid, value in values.items():
                    groups[tuple(key_for(context, pid, method))].append((x, value))
    return groups


def expected(model, x):
    return sum(a*b for a, b in zip(model["coef"], x)) if "coef" in model else model["median"]


def fit(train, calibration, method):
    calibrated = observations(calibration, method)
    models = {}
    for (pid, group), rows in observations(train, method).items():
        if len(rows) < MIN_WINDOWS:
            continue
        model = {"median": median(y for _, y in rows), "windows": len(rows)}
        if method != "median":
            size = len(rows[0][0])
            matrix = [[sum(x[i]*x[j] for x, _ in rows) + (0.2 if i == j else 0)
                       for j in range(size)] for i in range(size)]
            model["coef"] = _solve(matrix, [sum(x[i]*y for x, y in rows) for i in range(size)])
        independent = calibrated.get((pid, group), [])
        residuals = sorted(abs(y - expected(model, x)) for x, y in (independent if len(independent) >= 20 else rows))
        model["threshold"] = max(SIGNALS[int(pid)][2], residuals[math.ceil(.99 * len(residuals)) - 1])
        model["calibration_windows"] = len(independent)
        models.setdefault(pid, {})[group] = model
    return models


def score(trip, models, method, on_scored=None):
    stats = {str(pid): {"name": spec[0], "scored": 0, "valid": 0, "absolute_error": 0.,
                       "quality": Counter()} for pid, spec in SIGNALS.items()}
    events, pending = [], {}
    for index, at, context, x, values, quality in trip:
        for pid, (name, unit, _, persistence, _) in SIGNALS.items():
            summary = stats[str(pid)]
            summary["quality"][quality[pid]] += 1
            summary["valid"] += pid in values
            if not context or pid not in values:
                pending.pop(pid, None)
                continue
            _, group = key_for(context, pid, method)
            model = models.get(str(pid), {}).get(group)
            if not model:
                pending.pop(pid, None)
                continue
            observed = values[pid]
            estimate = expected(model, x)
            residual = observed - estimate
            summary["scored"] += 1
            summary["absolute_error"] += abs(residual)
            if on_scored is not None:
                on_scored(index, pid, estimate)
            if abs(residual) <= model["threshold"]:
                pending.pop(pid, None)
                continue
            direction = "high" if residual > 0 else "low"
            previous = pending.get(pid)
            if previous and previous[0] == index - 1 and previous[1:3] == (context, direction):
                count, event = previous[3] + 1, previous[4]
            else:
                count, event = 1, {"pid": pid, "signal": name, "unit": unit,
                                   "context": context, "direction": direction, "started_at": at.isoformat(),
                                   "suggested_check": CHECKS[pid]}
            pending[pid] = (index, context, direction, count, event)
            if count >= persistence:
                event.update(ended_at=at.isoformat(), observed=round(observed, 3),
                             expected=round(estimate, 3), threshold=round(model["threshold"], 3))
                if count == persistence:
                    event["detected_at"] = at.isoformat()
                    events.append(event)
    for summary in stats.values():
        error = summary.pop("absolute_error")
        summary["mae"] = round(error / summary["scored"], 4) if summary["scored"] else None
    return {"windows": len(trip), "checks": stats, "events": events}


def summarize(reports):
    summary = {}
    for pid, spec in SIGNALS.items():
        checks = [r["checks"][str(pid)] for r in reports]
        scored = sum(c["scored"] for c in checks)
        alerts = sum(e["pid"] == pid for r in reports for e in r["events"])
        summary[str(pid)] = {
            "signal": spec[0], "unit": spec[1], "scored_windows": scored,
            "eligible_sensor_windows": sum(c["valid"] for c in checks),
            "mae": round(sum(c["scored"] * (c["mae"] or 0) for c in checks) / scored, 4) if scored else None,
            "observed_alerts": alerts,
            "alerts_per_scored_hour": round(alerts * 720 / scored, 3) if scored else None,
        }
    return summary


def split_sessions(sessions):
    intervals = sorted((samples[0].at, samples[-1].at, key) for key, samples in sessions.items())
    for (_, end, old), (start, _, new) in zip(intervals, intervals[1:]):
        if start <= end:
            raise ValueError(f"Overlapping sessions: {old} and {new}. Keep one export in the dataset.")
    days = defaultdict(list)
    for start, _, key in intervals:
        days[start.date().isoformat()].append(key)
    groups = list(days.values())
    if len(groups) < 3:
        return [key for group in groups for key in group], [], []
    return [key for group in groups[:-2] for key in group], groups[-2], groups[-1]


def recordings(directory):
    sessions = read_sessions(directory)
    for key, samples in sessions.items():
        identities = {(s.pid, s.at) for s in samples}
        if len(identities) != len(samples):
            raise ValueError(f"Duplicate PID timestamps in {key}. Check for repeated CSV exports.")
    return sessions


def fetch(args):
    from ml.pipeline import Cloud, cloud_rows

    vehicle = str(UUID(args.vehicle_id))
    cloud = Cloud()
    directory = Path(args.csv_dir)
    directory.mkdir(parents=True, exist_ok=True)
    index_path = directory / "supabase-recordings.json"
    if not index_path.exists() and next(directory.glob("*.csv"), None) is not None:
        raise ValueError("Use an empty cache folder for the first Supabase fetch")
    index = load(index_path) if index_path.exists() else {
        "project": cloud.url, "vehicle_id": vehicle, "recordings": {},
    }
    if (index["project"], index["vehicle_id"]) != (cloud.url, vehicle):
        raise ValueError("Use a separate cache folder for each Supabase project and car")
    csv_fields = ("session_id", "sample_id", "pid", "value", "unit", "quality",
                  "requested_at_utc", "received_at_utc", "latency_ms", "ecu_source")
    counts = Counter()
    cursor = None
    failed = []
    while True:
        filters = {"vehicle_id": f"eq.{vehicle}", "uploaded_at": "not.is.null",
                   "order": "id.asc", "limit": "100"}
        if cursor is not None:
            filters["id"] = f"gt.{cursor}"
        sessions = cloud.rows("obd_recording_sessions", **filters)
        if not sessions:
            break
        for session in sessions:
            sid = str(UUID(session["id"]))
            target = directory / f"obd-{sid}.csv"
            metadata = {key: session[key] for key in ("uploaded_at", "sample_count", "storage_format")}
            cached = index["recordings"].get(sid)
            if cached and all(cached.get(key) == value for key, value in metadata.items()) and target.is_file():
                if hashlib.sha256(target.read_bytes()).hexdigest() == cached.get("sha256"):
                    counts["cached"] += 1
                    continue
            temporary = None
            try:
                rows = cloud_rows(cloud, session)
                with NamedTemporaryFile(mode="w", encoding="utf-8", newline="", dir=directory,
                                        suffix=".tmp", delete=False) as handle:
                    temporary = Path(handle.name)
                    writer = csv.DictWriter(handle, fieldnames=csv_fields)
                    writer.writeheader()
                    for row in rows:
                        timestamp(row["received_at"])
                        writer.writerow({
                            "session_id": sid, "sample_id": row["sample_id"],
                            "pid": f"{int(row['pid']):02X}", "value": row["value"],
                            "unit": row["unit"], "quality": row["quality"],
                            "requested_at_utc": row["requested_at"], "received_at_utc": row["received_at"],
                            "latency_ms": row["latency_ms"], "ecu_source": row.get("ecu_source"),
                        })
                metadata["sha256"] = hashlib.sha256(temporary.read_bytes()).hexdigest()
                temporary.replace(target)
                index["recordings"][sid] = metadata
                counts["downloaded"] += 1
            except (ValueError, KeyError, RuntimeError, OSError, EOFError) as error:
                failed.append(sid)
                print(f"Could not fetch {sid}: {error}")
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
        cursor = str(UUID(sessions[-1]["id"]))
    save(index_path, index)
    print(f"Completed recordings: {counts['downloaded']} downloaded, {counts['cached']} cached, {len(failed)} failed")
    if failed:
        raise SystemExit(1)


def train(args):
    sessions = recordings(args.csv_dir)
    train_ids, calibration_ids, test_ids = split_sessions(sessions)
    model = load(args.context_model)
    trips = {key: list(windows(samples, model)) for key, samples in sessions.items()}
    candidates = {}
    for method in ("median", "ridge", "pooled"):
        fitted = fit([trips[k] for k in train_ids], [trips[k] for k in calibration_ids], method)
        reports = [score(trips[k], fitted, method) for k in calibration_ids]
        candidates[method] = {"models": fitted, "calibration": dict(zip(calibration_ids, reports)),
                              "calibration_comparison": summarize(reports)}
    # Keep the prespecified ridge detector. Comparisons on the final test are
    # restricted to this candidate. Calibration reports expose the alternatives.
    selected = "ridge"
    if not candidates[selected]["models"]:
        raise ValueError("No sensor/context has enough valid training windows")
    bundle = {"schema": 1, "version": 1, "vehicle": args.vehicle, "context_model": model, "selected": selected,
              "candidates": candidates, "splits": {"train": train_ids, "calibration": calibration_ids,
                                                   "test": test_ids},
              "sessions": {key: digest(samples) for key, samples in sessions.items()}}
    save(args.out, bundle)


def adapt(args):
    bundle = load(args.bundle)
    if bundle["schema"] != 1 or bundle["vehicle"] != args.vehicle:
        raise ValueError("Bundle schema or vehicle mismatch")
    if Path(args.out).resolve() == Path(args.bundle).resolve():
        raise ValueError("Write the candidate to a new file")
    method = bundle["selected"]
    active = bundle["candidates"][method]["models"]
    sessions = recordings(args.csv_dir)
    split_sessions(sessions)
    accepted = []
    for key, samples in sessions.items():
        if key in bundle["sessions"]:
            raise ValueError(f"Already seen recording: {key}")
        trip = list(windows(samples, bundle["context_model"]))
        # This command accepts only explicitly reviewed reference drives.
        # A sustained deviation prevents the entire drive from entering the update.
        if score(trip, active, method)["events"]:
            raise ValueError(f"Reference drive has alerts: {key}")
        accepted.append(trip)
    additions = fit(accepted, [], method)
    changed = 0
    for pid, groups in additions.items():
        current = active.setdefault(pid, {})
        for group, fresh in groups.items():
            old = current.get(group)
            if old is None:
                current[group] = fresh
                changed += 1
                continue
            # Adjust only the intercept, using the observed delta under the
            # old predictor and retaining its threshold and slope.
            rows = observations(accepted, method)[(pid, group)]
            delta = median(y - expected(old, x) for x, y in rows)
            limit = old["threshold"] * .1
            if abs(delta) > old["threshold"] * .5:
                continue
            old["coef"][0] += max(-limit, min(limit, delta * .2))
            changed += 1
    if not changed:
        raise ValueError("No eligible sensor/context could be updated")
    bundle["version"] += 1
    bundle["adaptation"] = {"parent_sha256": hashlib.sha256(Path(args.bundle).read_bytes()).hexdigest(),
                            "reference_sessions": list(sessions), "changed_groups": changed}
    bundle["sessions"].update({key: digest(samples) for key, samples in sessions.items()})
    bundle["splits"]["train"].extend(sessions)
    save(args.out, bundle)


DTC_LINKS = {16: {"P0100", "P0101", "P0102", "P0103", "P0104"},
             5: {"P0115", "P0116", "P0117", "P0118", "P0119", "P0128"},
             15: {"P0110", "P0111", "P0112", "P0113", "P0114"},
             6: {"P0171", "P0172"}, 7: {"P0171", "P0172"}}


def analyze(args):
    bundle = load(args.bundle)
    if bundle["schema"] != 1 or bundle["vehicle"] != args.vehicle:
        raise ValueError("Bundle schema or vehicle mismatch")
    sessions = recordings(args.csv_dir)
    scans = load(args.dtc_json) if args.dtc_json else {}
    method = bundle["selected"]
    models = bundle["candidates"][method]["models"]
    ids = bundle["splits"]["test"] if args.test else list(sessions)
    if args.session:
        if args.session not in ids:
            raise ValueError("Requested session is not in the selected data split")
        ids = [args.session]
    if not ids:
        raise ValueError("Bundle has no untouched test day. Score a separate drive as a prospective check.")
    reports = []
    for key in ids:
        samples = sessions[key]
        fingerprint = digest(samples)
        if args.test and bundle["sessions"][key] != fingerprint:
            raise ValueError("Test recording differs from training manifest")
        if args.inject:
            pid, offset, start, duration = args.inject
            pid, offset, start, duration = int(pid, 0), float(offset), float(start), float(duration)
            if pid not in SIGNALS or not all(math.isfinite(v) for v in (offset, start, duration)) or start < 0 or duration <= 0:
                raise ValueError("Invalid injection settings")
            origin = samples[0].at
            affected = 0
            modified = []
            for sample in samples:
                elapsed = (sample.at - origin).total_seconds()
                if sample.pid == pid and sample.value is not None and sample.quality == "valid" and start <= elapsed < start + duration:
                    sample = replace(sample, value=sample.value + offset)
                    affected += 1
                modified.append(sample)
            if not affected:
                raise ValueError("Injection did not modify any valid samples")
            samples = modified
        result = score(list(windows(samples, bundle["context_model"])), models, method)
        codes = scans.get(key, [])
        for item in codes:
            if not re.fullmatch(r"[PCBU][0-3][0-9A-F]{3}", item["code"]) or not item["scan_time"] or not item["status"]:
                raise ValueError("DTC entries require a retrieved code, scan time and status")
            timestamp(item["scan_time"])
        for event in result["events"]:
            event["related_session_codes"] = [item for item in codes if item["code"] in DTC_LINKS[event["pid"]]]
        result["dtc_evidence"] = codes
        if args.inject:
            onset = origin + timedelta(seconds=start)
            end = onset + timedelta(seconds=duration)
            detected = [timestamp(event["detected_at"]) for event in result["events"]
                        if event["pid"] == pid and onset <= timestamp(event["started_at"]) < end]
            result["injection_result"] = {"modified_samples": affected, "detected": bool(detected),
                                          "delay_seconds": (min(detected) - onset).total_seconds() if detected else None}
        result.update(session=key, started_at=samples[0].at.isoformat(),
                      ended_at=samples[-1].at.isoformat(), sha256=fingerprint, simulation=args.inject,
                      used_for_fit_or_calibration=key in (bundle["splits"]["train"] + bundle["splits"]["calibration"]))
        reports.append(result)
    save(args.out, {"schema": 1, "vehicle": args.vehicle, "model": method,
                    "provisional": not bool(bundle["splits"]["calibration"]),
                    "model_version": bundle["version"], "summary": summarize(reports), "runs": reports})


def audit(args):
    sessions = recordings(args.csv_dir)
    split_sessions(sessions)
    save(args.out, {"sessions": [{"id": key, "sha256": digest(samples),
                                  "seconds": (samples[-1].at - samples[0].at).total_seconds(),
                                  "pid_quality": dict(Counter(f"{s.pid:02X}:{s.quality}" for s in samples))}
                                 for key, samples in sessions.items()]})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(required=True)
    download = commands.add_parser("fetch", help="Cache every completed Supabase recording for one vehicle")
    download.add_argument("--vehicle-id", required=True, help="Supabase vehicles.id UUID")
    download.add_argument("--csv-dir", required=True, help="Dedicated cache directory for this vehicle")
    download.set_defaults(action=fetch)
    for name, action in (("audit", audit), ("train", train), ("score", analyze), ("adapt", adapt)):
        cmd = commands.add_parser(name)
        cmd.add_argument("--csv-dir", required=True)
        cmd.add_argument("--out", required=True)
        cmd.set_defaults(action=action)
        if name != "audit":
            cmd.add_argument("--vehicle", required=True)
        if name == "train":
            cmd.add_argument("--context-model", default=CONTEXT_MODEL)
        if name == "score":
            cmd.add_argument("--bundle", required=True)
            cmd.add_argument("--test", action="store_true")
            cmd.add_argument("--session", help="Score only this session ID")
            cmd.add_argument("--inject", nargs=4, metavar=("PID", "OFFSET", "START_S", "DURATION_S"))
            cmd.add_argument("--dtc-json", help="Optional actual scan evidence, keyed by session ID")
        if name == "adapt":
            cmd.add_argument("--bundle", required=True)
            cmd.add_argument("--reviewed-reference", action="store_true", required=True,
                             help="Confirm these new drives were reviewed for DTCs and reference suitability")
    args = parser.parse_args()
    args.action(args)


if __name__ == "__main__":
    main()
