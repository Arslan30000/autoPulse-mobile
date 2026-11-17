"""Create static signal/label charts for reviewing existing weak annotations."""
import argparse
import csv
from collections import defaultdict
from datetime import datetime
import hashlib
from pathlib import Path


def run(labelled_windows, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    sessions = defaultdict(list)
    with Path(labelled_windows).open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            sessions[row["session_id"]].append(row)
    output = Path(out)
    output.mkdir(parents=True, exist_ok=True)
    states = ["engineOff", "idling", "cityCruising", "highwayCruising", "accelerating",
              "aggressiveAcceleration", "decelerating", "heavyLoad", "uncertain"]
    names = ["Engine off", "Idling", "City cruise", "Highway cruise", "Accelerating",
             "Strong accel.", "Decelerating", "Heavy load", "Uncertain"]
    images = []
    for session, rows in sessions.items():
        start = datetime.fromisoformat(rows[0]["at_utc"])
        times = [(datetime.fromisoformat(r["at_utc"])-start).total_seconds()/60 for r in rows]
        fig, axes = plt.subplots(5, 1, figsize=(15, 10), sharex=True, constrained_layout=True,
                                 gridspec_kw={"height_ratios": [1, 1, 1, 1, 1.5]})
        for axis, key, label, color in zip(axes[:4], ["speed_kph", "rpm", "load_pct", "acceleration_m_s2"],
                                         ["Speed (km/h)", "RPM", "ECU load (%)", "Speed slope (m/s²)"],
                                         ["#126576", "#4358a8", "#a36117", "#7a459a"]):
            values = [float(r[key]) if r[key] else float("nan") for r in rows]
            axis.plot(times, values, color=color, linewidth=.8)
            axis.set_ylabel(label)
            axis.grid(axis="y", alpha=.2)
        axes[3].axhline(0, color="black", linewidth=.5)
        label_codes = [states.index(r["training_state"]) for r in rows]
        axes[4].scatter(times, label_codes, c=label_codes, cmap="tab10", vmin=0, vmax=9, s=3)
        axes[4].set_yticks(range(len(states)), names, fontsize=8)
        axes[4].set_xlabel("Minutes since recording start (received timestamps)")
        axes[4].set_ylabel("Weak label")
        fig.suptitle(f"Yaris session {session}\n{start.isoformat()} · Provisional telemetry labels, no independent ground truth", fontsize=12)
        name = hashlib.sha256(session.encode()).hexdigest()[:16]+".png"
        fig.savefig(output/name, dpi=130)
        plt.close(fig)
        images.append(name)
    cards = "\n".join(f'<p><a href="{name}"><img src="{name}" style="width:100%;max-width:1500px" alt="Yaris signals and provisional labels"></a></p>' for name in images)
    (output/"index.html").write_text('<!doctype html><html lang="en"><meta charset="utf-8"><title>Yaris label review</title>'
        '<body style="font-family:sans-serif;margin:24px"><h1>Yaris weak-label review</h1>'
        '<p>Inspect the signals beside proposed labels. Blank signal gaps represent unavailable features. '
        'Uncertain periods were excluded from training. These plots and labels do not establish independent accuracy.</p>'
        '<p>Review the accompanying provisional-annotations.csv. Corrections and reviewer notes can be saved there; '
        'keep original telemetry unchanged.</p>'+cards+'</body></html>', encoding="utf-8")
    print(f"Saved {len(images)} review charts and index.html to {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--labelled-windows", default="ml/output/driving_context/bootstrap/labelled-windows.csv")
    parser.add_argument("--out", default="ml/output/driving_context/bootstrap/review")
    args = parser.parse_args()
    run(args.labelled_windows, args.out)
