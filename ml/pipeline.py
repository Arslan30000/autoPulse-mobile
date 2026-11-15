"""Run locally on exported CSVs or process completed Supabase jobs.

No raw recording is rewritten. A completed upload queues a job in PostgreSQL;
the scheduled worker claims jobs and writes versioned analysis results.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import datetime as dt
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from ml.model import csv_rows, fit, fit_regime, kaggle_windows, public_windows, recording_windows, score, validation


class Cloud:
    def __init__(self) -> None:
        self.url = os.environ["SUPABASE_URL"].rstrip("/")
        self.key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

    def request(self, method: str, path: str, data: object = None, *, storage: bool = False):
        root = "/storage/v1/object/authenticated/" if storage else "/rest/v1/"
        headers = {"apikey": self.key, "Authorization": "Bearer " + self.key}
        payload = None if data is None else json.dumps(data).encode()
        if payload is not None:
            headers["Content-Type"] = "application/json"
        if method in ("POST", "PATCH"):
            headers["Prefer"] = "return=representation,resolution=merge-duplicates"
        request = urllib.request.Request(self.url + root + path, payload, headers, method=method)
        with urllib.request.urlopen(request, timeout=60) as response:
            content = response.read()
        return content if storage else (json.loads(content) if content else None)

    def rows(self, table: str, **filters):
        query = urllib.parse.urlencode({"select": "*", **filters})
        return self.request("GET", table + "?" + query)

    def upsert(self, table: str, row: dict, conflict: str):
        path = table + "?on_conflict=" + urllib.parse.quote(conflict)
        return self.request("POST", path, [row])

    def claim(self):
        return self.request("POST", "rpc/claim_ml_jobs", {"max_jobs": 4}) or []


def _filter(value: str) -> str:
    return "eq." + value


def cloud_rows(cloud: Cloud, session: dict) -> list[dict]:
    sid = session["id"]
    if session["storage_format"] == "rows-v1":
        result = []
        cursor = 0
        while True:
            page = cloud.rows("obd_recording_samples", session_id=_filter(sid),
                              sample_id=f"gt.{cursor}", order="sample_id.asc", limit="1000")
            if not page:
                break
            result.extend(page)
            cursor = int(page[-1]["sample_id"])
    elif session["storage_format"] == "gzip-json-v1":
        result = []
        cursor = 0
        while True:
            chunks = cloud.rows("obd_recording_chunks", session_id=_filter(sid),
                                first_sample_id=f"gt.{cursor}", order="first_sample_id.asc", limit="64")
            if not chunks:
                break
            for chunk in chunks:
                if int(chunk["previous_sample_id"]) != cursor:
                    raise ValueError("Recording chunk chain is incomplete")
                object_path = urllib.parse.quote(chunk["object_path"], safe="/")
                compressed = cloud.request("GET", "obd-recordings/" + object_path, storage=True)
                if len(compressed) != int(chunk["byte_count"]) or hashlib.sha256(compressed).hexdigest() != chunk["sha256"]:
                    raise ValueError("Recording object failed integrity checks")
                plain = gzip.decompress(compressed)
                if len(plain) > 4 * 1024 * 1024:
                    raise ValueError("Recording object exceeds decoded limit")
                document = json.loads(plain)
                rows = document.get("rows", [])
                if document.get("version") != 1 or len(rows) != int(chunk["sample_count"]):
                    raise ValueError("Recording object has an unknown format or row count")
                result.extend(rows)
                cursor = int(chunk["last_sample_id"])
    else:
        raise ValueError("Unknown recording storage format")
    if len(result) != int(session["sample_count"]):
        raise ValueError(f"Recording has {len(result)} of {session['sample_count']} samples")
    return result


def local(args) -> None:
    paths = sorted(Path(args.csv_dir).glob("obd-*.csv"))
    if not paths:
        raise ValueError("No exported OBD recordings found")
    sessions = []
    details = []
    for path in paths:
        rows = csv_rows(path)
        windows, excluded = recording_windows(rows)
        if not windows:
            continue
        sessions.append((rows[0]["session_id"], windows))
        details.append({"file": path.name, "session_id": rows[0]["session_id"],
                        "valid_windows": len(windows), "excluded_windows": excluded,
                        "started_at": windows[0].at.isoformat()})
    ordered = sorted(sessions, key=lambda item: item[1][0].at)
    source = None
    if args.kaggle_csv:
        groups = kaggle_windows(args.kaggle_csv, set(args.kaggle_vehicles.split(",")))
        if len(groups) < 2:
            raise ValueError("Kaggle pretraining needs at least two usable vehicles")
        prior = fit([w for group in groups.values() for w in group])
        source = {"dataset": "cephasax/obdii-ds3", "vehicles": {id: len(w) for id, w in groups.items()},
                  "sha256": hashlib.sha256(Path(args.kaggle_csv).read_bytes()).hexdigest()}
    else:
        prior = fit(public_windows(args.public_csv)) if args.public_csv else None
    comparison = validation(ordered, prior)
    selected = comparison.get("selected", {"algorithm": "airflow-ridge-v1", "public_prior": False})
    all_windows = [w for _, group in ordered for w in group]
    model = (fit_regime(all_windows) if selected["algorithm"] == "airflow-regime-v1" else
             fit(all_windows, prior if selected["public_prior"] else None))
    if source:
        model["source"] = source
    result = {"model": model, "validation": comparison,
              "sessions": sorted(details, key=lambda row: row["started_at"]),
              "note": "Training runs establish a baseline, not independent fault-detection accuracy."}
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"sessions": len(ordered), "training_windows": model["training_windows"],
                      "validation": result["validation"], "output": args.out}))


def _sessions(cloud: Cloud, owner: str, vehicle: str) -> list[dict]:
    # Typical per-vehicle history is small; paginate to avoid PostgREST limits.
    result = []
    offset = 0
    while True:
        page = cloud.rows("obd_recording_sessions", owner_id=_filter(owner),
                          vehicle_id=_filter(vehicle), uploaded_at="not.is.null",
                          order="started_at.asc", limit="100", offset=str(offset))
        result.extend(page)
        if len(page) < 100:
            return result
        offset += len(page)


def process(cloud: Cloud, job: dict) -> None:
    owner, vehicle, sid = job["owner_id"], job["vehicle_id"], job["session_id"]
    session = cloud.rows("obd_recording_sessions", id=_filter(sid))
    if len(session) != 1 or not session[0]["uploaded_at"]:
        raise ValueError("Job refers to an incomplete or missing recording")
    existing = cloud.rows("ml_run_results", session_id=_filter(sid))
    if existing:
        cloud.request("PATCH", "ml_jobs?session_id=" + _filter(sid),
                      {"status": "completed", "finished_at": dt.datetime.now(dt.timezone.utc).isoformat()})
        return
    active = cloud.rows("ml_models", owner_id=_filter(owner), vehicle_id=_filter(vehicle), status="eq.active")
    if active:
        model_row = active[0]
        rows = cloud_rows(cloud, session[0])
        windows, excluded = recording_windows(rows)
        reference = sid in model_row["training_sessions"]
        alerts = [] if reference else score(windows, model_row["artifact"])
        status = "baseline" if reference else ("scored" if len(windows) >= 20 else "insufficient_data")
        model_id = model_row["id"]
    else:
        # Bootstrap once using all complete runs already present for this car.
        groups = []
        for run in _sessions(cloud, owner, vehicle):
            windows, excluded = recording_windows(cloud_rows(cloud, run))
            # Tiny connection tests and badly incomplete runs are not a baseline.
            if len(windows) >= 120 and len(windows) / (len(windows) + excluded) >= .8:
                groups.append((run["id"], windows))
        groups.sort(key=lambda item: item[1][0].at)
        if sum(len(w) for _, w in groups) < 100:
            rows = cloud_rows(cloud, session[0])
            windows, excluded = recording_windows(rows)
            status, alerts, model_id = "insufficient_data", [], None
        else:
            prior = json.loads((Path(__file__).parent / "public_prior.json").read_text(encoding="utf-8"))
            comparison = validation(groups, prior)
            chosen = comparison.get("selected", {"algorithm": "airflow-ridge-v1", "public_prior": False})
            training = [w for _, group in groups for w in group]
            artifact = (fit_regime(training) if chosen["algorithm"] == "airflow-regime-v1"
                        else fit(training, prior if chosen["public_prior"] else None))
            artifact["compared_public_source"] = prior["source"]
            saved = cloud.upsert("ml_models", {"owner_id": owner, "vehicle_id": vehicle,
                                "version": 1, "status": "active", "artifact": artifact,
                                "training_sessions": [id for id, _ in groups],
                                "training_windows": artifact["training_windows"],
                                "validation": comparison}, "owner_id,vehicle_id,version")
            model_id = saved[0]["id"]
            rows = cloud_rows(cloud, session[0])
            windows, excluded = recording_windows(rows)
            status, alerts = "baseline", []
    cloud.upsert("ml_run_results", {"session_id": sid, "owner_id": owner,
                 "vehicle_id": vehicle, "model_id": model_id, "status": status,
                 "valid_windows": len(windows), "excluded_windows": excluded,
                 "alert_count": len(alerts), "alerts": alerts,
                 "details": {"message": "Reference data" if status == "baseline" else
                             "Scored against frozen vehicle baseline"}}, "session_id")
    cloud.request("PATCH", "ml_jobs?session_id=" + _filter(sid),
                  {"status": "completed", "finished_at": dt.datetime.now(dt.timezone.utc).isoformat()})


def worker(args) -> None:
    cloud = Cloud()
    count = 0
    while count < args.max_jobs:
        jobs = cloud.claim()
        if not jobs:
            break
        for job in jobs:
            try:
                process(cloud, job)
                count += 1
                print(f"Completed analysis for {job['session_id']}")
            except Exception as error:
                cloud.request("PATCH", "ml_jobs?session_id=" + _filter(job["session_id"]),
                              {"status": "failed", "error": str(error)[:500]})
                print(f"Analysis failed for {job['session_id']}: {error}", file=sys.stderr)
                count += 1
    print(f"Processed {count} jobs")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    local_cmd = commands.add_parser("local", help="Train and evaluate exported recordings")
    local_cmd.add_argument("--csv-dir", required=True)
    local_cmd.add_argument("--public-csv", help="Compatible public telemetry with documented units")
    local_cmd.add_argument("--kaggle-csv", help="cephasax/obdii-ds3 dailyRoutes.csv (author's public mirror)")
    local_cmd.add_argument("--kaggle-vehicles", default="car11,car12", help="Explicit vehicle IDs for public pretraining")
    local_cmd.add_argument("--out", default="ml/output/local-baseline.json")
    worker_cmd = commands.add_parser("worker", help="Process completed Supabase recordings")
    worker_cmd.add_argument("--max-jobs", type=int, default=100)
    args = parser.parse_args()
    (local if args.command == "local" else worker)(args)


if __name__ == "__main__":
    main()
