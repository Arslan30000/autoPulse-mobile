import datetime as dt
import gzip
import hashlib
import json
import unittest

from ml.model import Window, fit, fit_regime, recording_windows, score, validation
from ml.pipeline import cloud_rows


def window(index: int, maf: float = 5.0) -> Window:
    return Window(dt.datetime(2026, 11, 10, tzinfo=dt.timezone.utc)
                  + dt.timedelta(seconds=index * 5),
                  {0x05: 88.0, 0x06: 0.0, 0x07: 5.0, 0x0C: 1500.0,
                   0x0D: 40.0, 0x0F: 30.0, 0x10: maf, 0x11: 20.0})


class ModelTests(unittest.TestCase):
    def test_missing_pid_never_becomes_zero_or_complete(self):
        rows = []
        for pid in ("05", "06", "07", "0C", "0D", "0F", "10", "11"):
            rows.append({"pid": pid, "quality": "valid", "value": "10",
                         "requested_at_utc": "2026-11-10T00:00:00Z"})
        complete, excluded = recording_windows(rows)
        self.assertEqual((len(complete), excluded), (1, 0))
        rows[-1]["quality"] = "noData"
        incomplete, excluded = recording_windows(rows)
        self.assertEqual((len(incomplete), excluded), (0, 1))

    def test_persistent_deviation_not_single_spike(self):
        training = [window(i, 5.0 + (i % 4) * .1) for i in range(120)]
        for learner in (fit, fit_regime):
            model = learner(training)
            short = [window(130, 20), window(131, 5), window(132, 5)]
            sustained = [window(130, 20), window(131, 20), window(132, 20)]
            self.assertEqual(score(short, model), [])
            self.assertEqual(len(score(sustained, model)), 1)

    def test_validation_uses_later_whole_day(self):
        sessions = []
        for day in (10, 11, 14):
            rows = [Window(w.at.replace(day=day), w.values) for w in
                    (window(i, 5 + (i % 3) * .1) for i in range(120))]
            sessions.append((str(day), rows))
        report = validation(sessions)
        self.assertEqual(report["status"], "held_out_day")
        self.assertEqual(report["session_ids"], ["14"])
        self.assertEqual(len(report["candidates"]), 2)

    def test_chunk_checksum_and_row_count_are_enforced(self):
        row = {"sample_id": 1, "pid": 12, "quality": "valid", "value": 900,
               "requested_at": "2026-11-10T00:00:00Z"}
        compressed = gzip.compress(json.dumps({"version": 1, "rows": [row]}).encode())
        manifest = {"previous_sample_id": 0, "first_sample_id": 1,
                    "last_sample_id": 1, "sample_count": 1,
                    "byte_count": len(compressed), "sha256": hashlib.sha256(compressed).hexdigest(),
                    "object_path": "owner/run/1.json.gz"}

        class FakeCloud:
            def rows(self, table, **filters):
                return [manifest] if table == "obd_recording_chunks" and filters["first_sample_id"] == "gt.0" else []
            def request(self, *args, **kwargs):
                return compressed

        session = {"id": "run", "storage_format": "gzip-json-v1", "sample_count": 1}
        self.assertEqual(cloud_rows(FakeCloud(), session), [row])
        manifest["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "integrity"):
            cloud_rows(FakeCloud(), session)


if __name__ == "__main__":
    unittest.main()
