"""Conservative telemetry-derived annotations; explicitly NOT human ground truth.

Labels define measured operating regimes. They cannot establish road grade,
driver intent, mechanical health or independent classification accuracy.
"""
import csv
from collections import Counter
from datetime import timedelta
import json
from pathlib import Path
from .replay import timeline

LABEL_SOURCE = "telemetry-weak-v1"
POLICY = {
    "version": LABEL_SOURCE,
    "stationary_speed_max_kph": 1, "moving_speed_min_kph": 3,
    "engine_off_rpm_max": 100, "engine_running_rpm_min": 400,
    "steady_abs_acceleration_max_m_s2": .15,
    "normal_acceleration_min_m_s2": .35, "normal_acceleration_max_m_s2": 1.2,
    "strong_acceleration_min_m_s2": 1.5, "strong_load_min_pct": 65,
    "strong_throttle_min_pct": 30, "deceleration_max_m_s2": -.65,
    "heavy_load_min_pct": 85, "cruise_load_max_pct": 70,
    "city_speed_max_kph": 65, "highway_speed_min_kph": 85,
    "min_run_seconds": 8, "feature_boundary_purge_seconds": 5,
    "trailing_boundary_purge_seconds": 1,
}


def proposed_label(values):
    p = POLICY
    if values is None:
        return "uncertain", "missing_or_stale_core_signals"
    speed, rpm, load, throttle, accel, *_ = values
    if speed <= p["stationary_speed_max_kph"]:
        if rpm <= p["engine_off_rpm_max"]:
            return "engineOff", "stationary_and_near_zero_rpm"
        if rpm >= p["engine_running_rpm_min"]:
            return "idling", "stationary_with_running_engine"
        return "uncertain", "engine_rpm_boundary"
    if speed < p["moving_speed_min_kph"] or rpm < p["engine_running_rpm_min"]:
        return "uncertain", "movement_or_engine_boundary"
    if accel <= p["deceleration_max_m_s2"]:
        return "decelerating", "sustained_negative_speed_slope"
    if (accel >= p["strong_acceleration_min_m_s2"] and load >= p["strong_load_min_pct"]
            and throttle >= p["strong_throttle_min_pct"]):
        return "aggressiveAcceleration", "strong_speed_slope_with_demand"
    if p["normal_acceleration_min_m_s2"] <= accel <= p["normal_acceleration_max_m_s2"]:
        return "accelerating", "positive_speed_slope"
    if abs(accel) > p["steady_abs_acceleration_max_m_s2"]:
        return "uncertain", "motion_transition_or_intensity_boundary"
    if load >= p["heavy_load_min_pct"]:
        return "heavyLoad", "steady_motion_and_high_reported_load"
    if load > p["cruise_load_max_pct"]:
        return "uncertain", "load_boundary"
    if speed <= p["city_speed_max_kph"]:
        return "cityCruising", "steady_lower_speed_band"
    if speed >= p["highway_speed_min_kph"]:
        return "highwayCruising", "steady_higher_speed_band"
    return "uncertain", "cruise_speed_boundary"


def label_sessions(sessions):
    records, intervals = [], []
    for session_id, samples in sessions.items():
        rows = []
        for at, values, *_ in timeline(samples):
            state, reason = proposed_label(values)
            rows.append({"session_id": session_id, "at": at, "values": values,
                         "proposed_state": state, "reason": reason, "state": "uncertain"})
        start = 0
        while start < len(rows):
            stop = start+1
            while stop < len(rows) and rows[stop]["proposed_state"] == rows[start]["proposed_state"]:
                stop += 1
            first, last = rows[start], rows[stop-1]
            state = first["proposed_state"]
            if state != "uncertain" and (last["at"]-first["at"]).total_seconds() >= POLICY["min_run_seconds"]:
                end = last["at"]
                intervals.append({"session_id": session_id, "start_utc": first["at"].isoformat(),
                                  "end_utc": end.isoformat(), "state": state, "secondary_flags": "",
                                  "confidence": "provisional", "reviewed": "false", "reviewer": "",
                                  "label_source": LABEL_SOURCE, "notes": first["reason"]})
                for row in rows[start:stop]:
                    if (row["at"] >= first["at"]+timedelta(seconds=POLICY["feature_boundary_purge_seconds"])
                            and row["at"] < end-timedelta(seconds=POLICY["trailing_boundary_purge_seconds"])):
                        row["state"] = state
            start = stop
        records.extend(rows)
    return records, intervals


def save_labels(records, intervals, output):
    from .features import FEATURES
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    fields = ["session_id", "start_utc", "end_utc", "state", "secondary_flags", "confidence", "reviewed", "reviewer", "label_source", "notes"]
    with (output/"provisional-annotations.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(intervals)
    with (output/"labelled-windows.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["session_id", "at_utc", "label_source", "reviewed", "proposed_state", "training_state", "reason", *FEATURES])
        for row in records:
            writer.writerow([row["session_id"], row["at"].isoformat(), LABEL_SOURCE, "false",
                             row["proposed_state"], row["state"], row["reason"], *(row["values"] or [""]*len(FEATURES))])
    counts = Counter(r["state"] for r in records)
    summary = {"label_source": LABEL_SOURCE, "reviewed": False, "policy": POLICY,
               "evaluation_ticks": len(records), "training_state_counts": counts,
               "intervals": len(intervals), "limitation": "Telemetry-derived provisional labels, not independent ground truth"}
    (output/"label-summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary
