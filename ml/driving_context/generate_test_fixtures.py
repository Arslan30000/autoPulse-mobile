"""Generate SYNTHETIC SOFTWARE TEST fixtures, never a deployable trained model."""
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import random
from .features import FEATURES, FeatureBuffer, Sample
from .rules import evaluate, Stabilizer
from .train import export_forest, votes, predict


def generate():
    from sklearn.ensemble import RandomForestClassifier
    rng = random.Random(17)
    xs, ys = [], []
    for i in range(160):
        speed = rng.uniform(10, 125)
        xs.append([speed, rng.uniform(900, 3000), 40, 20, 0, 1, 100, 2])
        ys.append("cityCruising" if speed < 80 else "highwayCruising")
    forest = RandomForestClassifier(n_estimators=20, max_depth=4, min_samples_leaf=3,
                                    random_state=17, n_jobs=1).fit(xs, ys)
    artifact = export_forest(forest, version="synthetic-test-only",
                             provenance={"synthetic_test_only": True, "not_for_deployment": True})
    vectors = xs[:20] + [[80, 1600, 40, 20, 0, 0, 0, 0]]
    for tree in artifact["trees"]:
        for node in tree:
            if "feature" in node:
                for delta in (-1e-6, 0, 1e-6):
                    vector = [80, 1600, 40, 20, 0, 0, 0, 0]
                    vector[node["feature"]] = node["threshold"]+delta
                    vectors.append(vector)
    reference = forest.predict_proba(vectors).tolist()
    for x, expected in zip(vectors, reference):
        assert all(abs(a-b) < 1e-12 for a, b in zip(votes(artifact, x), expected))
    base = datetime(2026, 11, 10, tzinfo=timezone.utc)
    buffer, stabilized = FeatureBuffer(), Stabilizer()
    stream = []
    for i in range(40):
        for pid, value in [(0x04, 45 if i < 20 else 90), (0x11, 20), (0x0C, 1500), (0x0D, 40+i*.1)]:
            at = base+timedelta(seconds=i, milliseconds=(0x04, 0x11, 0x0C, 0x0D).index(pid)*20)
            quality = "invalid" if i == 30 and pid == 0x0D else "valid"
            sample = Sample(pid, at, value if quality == "valid" else None, quality)
            buffer.add(sample)
            stabilized.step(buffer, at)
            stream.append({"pid": pid, "at": at.isoformat(), "value": sample.value, "quality": quality,
                           "features": buffer.extract(at), "confirmed_state": stabilized.state})
    result = {"warning": "Synthetic software tests, not real accuracy evidence or a production asset",
              "features": FEATURES, "model": artifact,
              "predictions": [{"values": x, "votes": v, "state": predict(artifact, x)} for x, v in zip(vectors, reference)],
              "stream": stream,
              "rules": [{"values": x, "state": evaluate(x)} for x in [
                  [0, 800, 40, 15, 0, 0, 0, 0], [0, 4000, 40, 80, 0, 0, 0, 0],
                  [0, 0, 0, 15, 0, 0, 0, 0], [40, 1500, 40, 20, 0, 0, 0, 0],
                  [100, 2200, 45, 20, 0, 0, 0, 0], [60, 2000, 90, 40, 0, 0, 0, 0],
                  [40, 2500, 65, 35, 2, 0, 0, 0], [40, 1500, 45, 20, -.8, 0, 0, 0],
                  [40, 1500, 45, 20, .4, 0, 0, 0]]]}
    target = Path("test/fixtures/driving_context_parity.json")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, indent=2, allow_nan=False), encoding="utf-8")
    print(f"Synthetic parity fixture saved to {target}; {len(vectors)} model cases; {len(stream)} PID attempts")


if __name__ == "__main__":
    generate()
