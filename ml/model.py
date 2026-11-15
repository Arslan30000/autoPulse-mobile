"""Small, reproducible per-vehicle airflow baseline; no fault labels assumed."""
from __future__ import annotations

import csv
import datetime as dt
import math
import statistics
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

WINDOW_SECONDS = 5
REQUIRED = {0x05, 0x06, 0x07, 0x0C, 0x0D, 0x0F, 0x10, 0x11}


@dataclass(frozen=True)
class Window:
    at: dt.datetime
    values: dict[int, float]


def _timestamp(value: str) -> dt.datetime:
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("Recording timestamps must include a timezone")
    return parsed


def _pid(value: object) -> int:
    # CSV exports use hexadecimal strings; cloud chunks use integer PID codes.
    return int(value, 16) if isinstance(value, str) else int(value)


def csv_rows(path: str | Path) -> list[dict]:
    with open(path, encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def recording_windows(rows: list[dict]) -> tuple[list[Window], int]:
    """Use complete, non-overlapping windows; never fabricate simultaneous PIDs."""
    if not rows:
        return [], 0
    start = min(_timestamp(r.get("requested_at_utc") or r["requested_at"]) for r in rows)
    buckets: dict[int, dict[int, tuple[dt.datetime, float]]] = defaultdict(dict)
    for row in rows:
        if row.get("quality") != "valid" or row.get("value") in (None, ""):
            continue
        pid = _pid(row["pid"])
        if pid not in REQUIRED:
            continue
        moment = _timestamp(row.get("requested_at_utc") or row["requested_at"])
        offset = (moment - start).total_seconds()
        if offset < 0:
            continue
        index = int(offset // WINDOW_SECONDS)
        value = float(row["value"])
        if not math.isfinite(value):
            continue
        previous = buckets[index].get(pid)
        if previous is None or moment >= previous[0]:
            buckets[index][pid] = (moment, value)
    total = int(max((_timestamp(r.get("requested_at_utc") or r["requested_at"]) - start).total_seconds() for r in rows) // WINDOW_SECONDS) + 1
    result = [
        Window(start + dt.timedelta(seconds=index * WINDOW_SECONDS),
               {pid: sample[1] for pid, sample in values.items()})
        for index, values in sorted(buckets.items()) if REQUIRED <= values.keys()
    ]
    return result, max(0, total - len(result))


def features(window: Window) -> list[float]:
    p = window.values
    rpm = p[0x0C] / 3000.0
    throttle = p[0x11] / 100.0
    # Load is deliberately excluded: some ECUs calculate it from airflow.
    return [1.0, rpm, p[0x0D] / 120.0, throttle,
            p[0x05] / 100.0, p[0x0F] / 60.0, rpm * throttle]


def _solve(matrix: list[list[float]], vector: list[float]) -> list[float]:
    """Partial-pivot Gaussian elimination for the seven ridge coefficients."""
    size = len(vector)
    a = [row[:] + [vector[i]] for i, row in enumerate(matrix)]
    for column in range(size):
        pivot = max(range(column, size), key=lambda i: abs(a[i][column]))
        if abs(a[pivot][column]) < 1e-12:
            raise ValueError("Baseline data cannot fit the model")
        a[column], a[pivot] = a[pivot], a[column]
        scale = a[column][column]
        a[column] = [v / scale for v in a[column]]
        for row in range(size):
            if row == column:
                continue
            factor = a[row][column]
            a[row] = [a[row][j] - factor * a[column][j] for j in range(size + 1)]
    return [a[i][-1] for i in range(size)]


def fit(windows: list[Window], prior: dict | None = None) -> dict:
    usable = [w for w in windows if w.values[0x0C] >= 500 and w.values[0x10] >= 0]
    if len(usable) < 100:
        raise ValueError("At least 100 complete, engine-running windows are needed")
    size = len(features(usable[0]))
    matrix = [[0.0] * size for _ in range(size)]
    vector = [0.0] * size
    for window in usable:
        x, target = features(window), window.values[0x10]
        for i in range(size):
            vector[i] += x[i] * target
            for j in range(size):
                matrix[i][j] += x[i] * x[j]
    # A public model is a *prior*, never a substitute for vehicle calibration.
    strength = min(20.0, len(usable) * 0.02) if prior else 0.0
    for i in range(size):
        penalty = strength if prior else (0.01 if i else 1e-9)
        matrix[i][i] += penalty
        if prior:
            vector[i] += strength * float(prior["coefficients"][i])
    coefficients = _solve(matrix, vector)
    errors = [abs(w.values[0x10] - sum(a * b for a, b in zip(features(w), coefficients))) for w in usable]
    threshold = max(1.0, sorted(errors)[min(len(errors) - 1, math.ceil(.99 * len(errors)) - 1)])
    return {"algorithm": "airflow-ridge-v1", "window_seconds": WINDOW_SECONDS,
            "coefficients": coefficients, "threshold_maf_g_s": threshold,
            "training_windows": len(usable), "public_prior": prior is not None}


def _regime(window: Window) -> str:
    p = window.values
    temperature = "cold" if p[0x05] < 70 else "warm"
    speed = "idle" if p[0x0D] < 5 else "urban" if p[0x0D] < 60 else "fast"
    rpm = "low" if p[0x0C] < 1500 else "mid" if p[0x0C] < 3000 else "high"
    return f"{temperature}:{speed}:{rpm}"


def fit_regime(windows: list[Window]) -> dict:
    """A deliberately simple comparison model: conditional robust medians."""
    groups: dict[str, list[float]] = defaultdict(list)
    for window in windows:
        if window.values[0x0C] >= 500:
            groups[_regime(window)].append(window.values[0x10])
    all_values = [value for group in groups.values() for value in group]
    if len(all_values) < 100:
        raise ValueError("At least 100 complete windows are needed")
    global_center = statistics.median(all_values)
    residuals = [abs(value - statistics.median(group)) for group in groups.values() for value in group]
    threshold = max(1.0, sorted(residuals)[min(len(residuals) - 1, math.ceil(.99 * len(residuals)) - 1)])
    return {"algorithm": "airflow-regime-v1", "window_seconds": WINDOW_SECONDS,
            "centers": {key: statistics.median(group) for key, group in groups.items() if len(group) >= 20},
            "global_center": global_center, "threshold_maf_g_s": threshold,
            "training_windows": len(all_values), "public_prior": False}


def expected_maf(window: Window, model: dict) -> float:
    if model["algorithm"] == "airflow-ridge-v1":
        return sum(a * b for a, b in zip(features(window), model["coefficients"]))
    if model["algorithm"] == "airflow-regime-v1":
        return model["centers"].get(_regime(window), model["global_center"])
    raise ValueError("Unknown model algorithm")


def score(windows: list[Window], model: dict) -> list[dict]:
    """Three consecutive high-residual windows form one persistent event."""
    alerts: list[dict] = []
    streak: list[tuple[Window, float]] = []
    previous_at: dt.datetime | None = None
    def flush() -> None:
        if len(streak) >= 3:
            alerts.append({"started_at": streak[0][0].at.isoformat(),
                           "ended_at": streak[-1][0].at.isoformat(),
                           "windows": len(streak),
                           "peak_residual_maf_g_s": round(max(e for _, e in streak), 3),
                           "signal": "MAF", "meaning": "Airflow differs from this vehicle's baseline"})
        streak.clear()
    for window in windows:
        if previous_at is not None and (window.at - previous_at).total_seconds() != WINDOW_SECONDS:
            flush()
        previous_at = window.at
        if window.values[0x0C] < 500:
            flush()
            continue
        expected = expected_maf(window, model)
        error = abs(window.values[0x10] - expected)
        if error > model["threshold_maf_g_s"]:
            streak.append((window, error))
        else:
            flush()
    flush()
    return alerts


def validation(sessions: list[tuple[str, list[Window]]], prior: dict | None = None) -> dict:
    """Evaluate on the latest whole recording; never split adjacent rows."""
    if len(sessions) < 3:
        return {"status": "insufficient_sessions"}
    latest_day = sessions[-1][1][0].at.date()
    reference = [(sid, rows) for sid, rows in sessions if rows[0].at.date() < latest_day]
    held_sessions = [(sid, rows) for sid, rows in sessions if rows[0].at.date() == latest_day]
    if len(reference) < 2:
        return {"status": "insufficient_prior_days"}
    training = [w for _, rows in reference for w in rows]
    held = [w for _, rows in held_sessions for w in rows]
    candidates = [fit(training), fit_regime(training)]
    if prior is not None:
        candidates.append(fit(training, prior))
    duration_h = max(len(held) * WINDOW_SECONDS / 3600, 1 / 3600)
    comparisons = []
    for candidate in candidates:
        alerts = score(held, candidate)
        # Perturbation checks software sensitivity only, not real-fault accuracy.
        changed = [Window(w.at, {**w.values, 0x10: w.values[0x10] + 12.0}) for w in held]
        errors = [abs(w.values[0x10] - expected_maf(w, candidate)) for w in held]
        comparisons.append({"algorithm": candidate["algorithm"],
                            "public_prior": candidate["public_prior"],
                            "maf_mae_g_s": round(statistics.mean(errors), 3),
                            "alerts": len(alerts),
                            "alerts_per_scored_hour": round(len(alerts) / duration_h, 3),
                            "perturbation_alerts": len(score(changed, candidate))})
    winner = min(comparisons, key=lambda item: (item["maf_mae_g_s"], item["alerts_per_scored_hour"]))
    return {"status": "held_out_day", "session_ids": [sid for sid, _ in held_sessions],
            "valid_windows": len(held), "candidates": comparisons,
            "selected": {"algorithm": winner["algorithm"], "public_prior": winner["public_prior"]},
            "note": "Unlabelled runs do not establish fault-detection accuracy."}


def kaggle_windows(path: str | Path, vehicles: set[str] | None = None) -> dict[str, list[Window]]:
    """Original author's mirror of Kaggle cephasax/obdii-ds3 dailyRoutes.csv.

    The semicolon file uses decimal commas and may omit readings. Only rows
    with matching raw signals and a known vehicle ID can enter pretraining.
    """
    required = {0x0C: "ENGINE_RPM", 0x0D: "SPEED", 0x05: "ENGINE_COOLANT_TEMP",
                0x0F: "AIR_INTAKE_TEMP", 0x10: "MAF", 0x11: "THROTTLE_POS"}
    groups: dict[str, list[Window]] = defaultdict(list)
    with open(path, encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream, delimiter=";")
        if not set(required.values()) <= set(reader.fieldnames or []):
            raise ValueError("Kaggle file does not have the expected OBD columns")
        for row in reader:
            vehicle = row.get("VEHICLE_ID", "")
            if not vehicle or (vehicles and vehicle not in vehicles):
                continue
            try:
                values = {pid: float(row[name].replace(",", ".").replace("%", "").replace("RPM", ""))
                          for pid, name in required.items()}
                if not all(math.isfinite(value) for value in values.values()):
                    continue
                timestamp = dt.datetime.fromtimestamp(int(row["TIMESTAMP"]) / 1000, tz=dt.timezone.utc)
                groups[vehicle].append(Window(timestamp, values))
            except (TypeError, ValueError, OverflowError):
                continue
    return dict(groups)


def public_windows(path: str | Path) -> list[Window]:
    """Import compatible, row-aligned public telemetry with explicit units."""
    aliases = {
        0x0C: ("RPM", "ENGINE_RPM", "Engine RPM(rpm)"),
        0x0D: ("SPEED", "VEHICLE_SPEED", "Vehicle Speed[km/h]"),
        0x05: ("COOLANT_TEMP", "COOLANT_TEMPERATURE"),
        0x0F: ("INTAKE_TEMP", "INTAKE_AIR_TEMP"),
        0x10: ("MAF", "MAF[g/sec]", "MAF_GRAMS_SEC"),
        0x11: ("THROTTLE_POS", "THROTTLE_POSITION"),
    }
    windows = []
    with open(path, encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        fields = set(reader.fieldnames or [])
        columns = {pid: next((name for name in names if name in fields), None) for pid, names in aliases.items()}
        missing = [hex(pid) for pid, name in columns.items() if name is None]
        if missing:
            raise ValueError(f"Public dataset lacks required columns: {', '.join(missing)}")
        for index, row in enumerate(reader):
            try:
                values = {pid: float(row[name]) for pid, name in columns.items()}
                if all(math.isfinite(v) for v in values.values()):
                    windows.append(Window(dt.datetime(2000, 1, 1, tzinfo=dt.timezone.utc)
                                          + dt.timedelta(seconds=index * WINDOW_SECONDS), values))
            except (ValueError, TypeError):
                continue
    return windows
