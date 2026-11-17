import copy
import csv
import contextlib
import importlib.util
import io
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import tempfile
import unittest

from ml.driving_context.features import FeatureBuffer, Sample
from ml.driving_context.rules import evaluate, Stabilizer
from ml.driving_context.train import annotations, temporal_split, votes, predict, run


class ContextTests(unittest.TestCase):
    @unittest.skipUnless(importlib.util.find_spec("sklearn"), "Install context training requirements to test fitting/export")
    def test_training_export_end_to_end_on_explicitly_synthetic_reviewed_fixture(self):
        # Deliberately synthetic labels differ from the rules' 80 km/h split,
        # exercising candidate selection and export without touching real data.
        with tempfile.TemporaryDirectory() as root:
            directory = Path(root)
            label_path = directory/"labels.csv"
            fields = ["session_id", "start_utc", "end_utc", "state", "reviewed", "reviewer", "confidence"]
            with label_path.open("w", newline="") as label_handle:
                labels = csv.writer(label_handle)
                labels.writerow(fields)
                for day in (10, 11, 14):
                    start = datetime(2026, 11, day, tzinfo=timezone.utc)
                    session = f"synthetic-test-only-{day}"
                    with (directory/f"{day}.csv").open("w", newline="") as data_handle:
                        writer = csv.writer(data_handle)
                        writer.writerow(["session_id", "pid", "value", "quality", "received_at_utc"])
                        for i in range(260):
                            at = start+timedelta(seconds=i)
                            speed = 50 if i < 130 else 65
                            for pid, value in [("04", 40), ("11", 20), ("0C", 1600), ("0D", speed)]:
                                writer.writerow([session, pid, value, "valid", at.isoformat()])
                    labels.writerow([session, start.isoformat(), (start+timedelta(seconds=130)).isoformat(), "cityCruising", "true", "Synthetic software fixture", "high"])
                    labels.writerow([session, (start+timedelta(seconds=130)).isoformat(), (start+timedelta(seconds=260)).isoformat(), "highwayCruising", "true", "Synthetic software fixture", "high"])
            with contextlib.redirect_stdout(io.StringIO()):
                # Keep annotations separate from the recording input directory.
                recording_dir = directory/"recordings"
                recording_dir.mkdir()
                for day in (10, 11, 14):
                    (directory/f"{day}.csv").replace(recording_dir/f"{day}.csv")
                result = run(recording_dir, label_path, directory/"out")
            self.assertFalse(result["release_approved"])
            self.assertIsNotNone(result["artifact"])
            model = json.loads((directory/"out"/result["artifact"]).read_text())
            self.assertTrue(model["reviewed_labels"])
            self.assertFalse(set(model["provenance"]["training_sessions"]) & set(model["provenance"]["test_sessions"]))
            self.assertEqual(model["provenance"]["test_day"], "2026-11-14")
            self.assertTrue((directory/"out"/"parity.json").is_file())

    def test_committed_python_dart_fixture_matches_python(self):
        fixture = json.loads(Path("test/fixtures/driving_context_parity.json").read_text())
        buffer, stabilizer = FeatureBuffer(), Stabilizer()
        for row in fixture["stream"]:
            at = datetime.fromisoformat(row["at"])
            buffer.add(Sample(row["pid"], at, row["value"], row["quality"]))
            stabilizer.step(buffer, at)
            actual = buffer.extract(at)
            if row["features"] is None:
                self.assertIsNone(actual)
            else:
                for a, b in zip(actual, row["features"]):
                    self.assertAlmostEqual(a, b, places=10)
            self.assertEqual(stabilizer.state, row["confirmed_state"])
        for row in fixture["rules"]:
            self.assertEqual(evaluate(row["values"]), row["state"])
        for row in fixture["predictions"]:
            self.assertEqual(predict(fixture["model"], row["values"]), row["state"])
            for a, b in zip(votes(fixture["model"], row["values"]), row["votes"]):
                self.assertAlmostEqual(a, b, places=12)

    def test_missing_failed_future_stale_and_invalid_ranges_abstain(self):
        now = datetime(2026, 11, 10, tzinfo=timezone.utc)
        buffer = FeatureBuffer()
        self.assertIsNone(buffer.extract(now))
        for i in range(4):
            at = now+timedelta(seconds=i)
            for pid, value in [(0x0D, 36+i*3.6), (0x0C, 1600), (4, 40), (0x11, 20)]:
                buffer.add(Sample(pid, at, value))
        end = now+timedelta(seconds=3)
        self.assertAlmostEqual(buffer.extract(end)[4], 1)
        self.assertIsNone(buffer.extract(now))  # future values cannot leak backwards
        self.assertIsNone(buffer.extract(end+timedelta(seconds=6)))
        for value, quality in [(None, "noData"), (101, "valid"), (float("nan"), "valid")]:
            candidate = copy.deepcopy(buffer)
            candidate.add(Sample(4, end+timedelta(milliseconds=1), value, quality))
            self.assertIsNone(candidate.extract(end+timedelta(milliseconds=1)))

    def test_training_rejects_missing_or_overlapping_reviewed_labels(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root)/"annotations.csv"
            fields = ["session_id", "start_utc", "end_utc", "state", "reviewed", "reviewer", "confidence"]
            with path.open("w", newline="") as handle:
                csv.writer(handle).writerow(fields)
            with self.assertRaisesRegex(ValueError, "No reviewed"):
                annotations(path)
            with path.open("a", newline="") as handle:
                writer = csv.writer(handle)
                for state in ("idling", "cityCruising"):
                    writer.writerow(["session", "2026-11-10T00:00:00Z", "2026-11-10T00:01:00Z", state, "true", "Reviewer", "high"])
            with self.assertRaisesRegex(ValueError, "Overlapping"):
                annotations(path)

    def test_tuning_and_test_are_separate_whole_days(self):
        rows = [{"day": f"2026-11-{day:02d}", "session_id": str(day)} for day in (10, 10, 11, 11, 14, 14)]
        train, tune, test = temporal_split(rows)
        self.assertEqual({r["session_id"] for r in train}, {"10"})
        self.assertEqual({r["session_id"] for r in tune}, {"11"})
        self.assertEqual({r["session_id"] for r in test}, {"14"})
        with self.assertRaisesRegex(ValueError, "three labelled"):
            temporal_split(rows[:4])


if __name__ == "__main__":
    unittest.main()
