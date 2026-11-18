"""Create private local Dart parity fixtures from the Python scorer."""
import argparse
from dataclasses import replace
from pathlib import Path

from ml.diagnostics import load, recordings, save, score, windows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv-dir", required=True)
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    model = load(args.bundle)
    models = model["candidates"]["ridge"]["models"]
    sessions = recordings(args.csv_dir)
    variants = [(key, None) for key in sessions]
    wanted = {"91da1bf0": 165, "6a8e4842": 120}
    variants.extend((key, wanted[key[:8]]) for key in sessions if key[:8] in wanted)
    for index, (key, start) in enumerate(variants):
        original = sessions[key]
        origin = original[0].at
        samples = [
            replace(s, value=s.value + 12)
            if start is not None and s.pid == 16 and s.quality == "valid"
            and s.value is not None and start <= (s.at-origin).total_seconds() < start + 60
            else s for s in original
        ]
        trip = list(windows(samples, model["context_model"]))
        trace = []
        expected_report = score(trip, models, "ridge", on_scored=lambda w, p, e: trace.append([w, p, e]))
        save(Path(args.out) / f"replay-{index:02}.json", {
            "id": key, "simulation": start, "context_model": model["context_model"],
            "models": models, "expected": expected_report, "trace": trace,
            "samples": [[s.pid, s.at.isoformat(), s.value, s.quality] for s in samples],
        })


if __name__ == "__main__":
    main()
