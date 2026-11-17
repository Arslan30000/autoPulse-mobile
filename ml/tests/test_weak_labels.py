import contextlib
import csv
from datetime import datetime, timedelta, timezone
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

from ml.driving_context.bootstrap import run
from ml.driving_context.features import Sample
from ml.driving_context.train import annotations
from ml.driving_context.weak_labels import LABEL_SOURCE, label_sessions, proposed_label, save_labels


class WeakLabelTests(unittest.TestCase):
    def test_conservative_operating_labels_abstain_at_boundaries(self):
        cases = [([0, 800, 40, 15, 0, 0, 0, 0], "idling"),
                 ([0, 0, 0, 15, 0, 0, 0, 0], "engineOff"),
                 ([40, 1600, 40, 20, 0, 0, 0, 0], "cityCruising"),
                 ([100, 2200, 40, 20, 0, 0, 0, 0], "highwayCruising"),
                 ([40, 1600, 90, 40, 0, 0, 0, 0], "heavyLoad"),
                 ([40, 1600, 40, 20, .7, 0, 0, 0], "accelerating"),
                 ([40, 2000, 70, 40, 2, 0, 0, 0], "aggressiveAcceleration"),
                 ([40, 1600, 40, 20, -1, 0, 0, 0], "decelerating"),
                 ([75, 1600, 40, 20, 0, 0, 0, 0], "uncertain"),
                 ([40, 1600, 75, 20, 0, 0, 0, 0], "uncertain"),
                 (None, "uncertain")]
        for values, expected in cases:
            self.assertEqual(proposed_label(values)[0], expected)

    def test_generated_labels_never_claim_human_review_and_preserve_source(self):
        at = datetime(2026, 11, 10, tzinfo=timezone.utc)
        samples = [Sample(pid, at+timedelta(seconds=i), value)
                   for i in range(40) for pid, value in [(4, 40), (0x11, 20), (0x0C, 800), (0x0D, 0)]]
        original = list(samples)
        records, intervals = label_sessions({"test": samples})
        self.assertEqual(samples, original)
        self.assertGreater(sum(r["state"] == "idling" for r in records), 0)
        self.assertTrue(all(r["reviewed"] == "false" and not r["reviewer"] for r in intervals))
        self.assertTrue(all(r["label_source"] == LABEL_SOURCE for r in intervals))
        with tempfile.TemporaryDirectory() as directory:
            save_labels(records, intervals, directory)
            with self.assertRaisesRegex(ValueError, "No reviewed"):
                annotations(Path(directory)/"provisional-annotations.csv")

    @unittest.skipUnless(importlib.util.find_spec("sklearn"), "Install context training requirements")
    def test_bootstrap_fits_real_format_data_with_explicit_weak_provenance_and_day_holdout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inputs = root/"recordings"
            inputs.mkdir()
            for day in (10, 11):
                start = datetime(2026, 11, day, tzinfo=timezone.utc)
                with (inputs/f"{day}.csv").open("w", newline="") as handle:
                    writer = csv.writer(handle)
                    writer.writerow(["session_id", "pid", "value", "quality", "received_at_utc"])
                    for i in range(240):
                        for pid, value in [("04", 40 if i < 120 else 90), ("11", 30), ("0C", 1600), ("0D", 40)]:
                            writer.writerow([f"test-{day}", pid, value, "valid", (start+timedelta(seconds=i)).isoformat()])
            with contextlib.redirect_stdout(io.StringIO()):
                report = run(inputs, root/"out")
            self.assertFalse(report["release_approved"])
            self.assertIsNone(report["provenance"]["independent_context_accuracy"])
            self.assertEqual(report["provenance"]["training_sessions"], ["test-10"])
            self.assertEqual(report["provenance"]["test_sessions"], ["test-11"])
            self.assertGreater(report["forest_training_windows"], 100)
            self.assertEqual(len(report["models"]), 3)
            artifact = json.loads((root/"out"/report["selected_artifact"]).read_text())
            self.assertFalse(artifact["reviewed_labels"])
            self.assertTrue(artifact["experimental"])
            self.assertEqual(artifact["label_source"], LABEL_SOURCE)


if __name__ == "__main__":
    unittest.main()
