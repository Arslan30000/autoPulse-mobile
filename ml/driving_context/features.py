"""Version-one causal features; mirror lib/services/driving_context/context_features.dart."""
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
import math

FEATURES = ["speed_kph", "rpm", "load_pct", "throttle_pct", "acceleration_m_s2",
            "speed_range_kph", "rpm_range", "throttle_range_pct"]
CORE = (0x0D, 0x0C, 0x04, 0x11)


def timestamp(value):
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if result.tzinfo is None:
        raise ValueError("Recording and annotation timestamps must include a timezone")
    return result


@dataclass(frozen=True)
class Sample:
    pid: int
    at: datetime
    value: float | None
    quality: str = "valid"

    @classmethod
    def from_row(cls, row):
        return cls(int(row["pid"], 16), timestamp(row["received_at_utc"]),
                   float(row["value"]) if row["value"] else None, row["quality"])

    @property
    def valid(self):
        maximum = {0x0D: 255, 0x0C: 16383.75}.get(self.pid, 100)
        return (self.quality == "valid" and self.value is not None
                and math.isfinite(self.value) and 0 <= self.value <= maximum)


class FeatureBuffer:
    def __init__(self):
        self.latest = {}
        self.history = defaultdict(list)

    def add(self, sample):
        if sample.pid not in CORE:
            return
        old = self.latest.get(sample.pid)
        if old and sample.at <= old.at:
            return
        self.latest[sample.pid] = sample
        self.history[sample.pid] = [s for s in self.history[sample.pid]
                                    if (sample.at - s.at).total_seconds() <= 5]
        self.history[sample.pid].append(sample)
        self.history[sample.pid] = self.history[sample.pid][-100:]

    def extract(self, now):
        for pid in CORE:
            sample = self.latest.get(pid)
            if (sample is None or not sample.valid
                    or not 0 <= (now - sample.at).total_seconds() <= (3 if pid in (0x0D, 0x0C) else 5)):
                return None
        recent = {pid: [s for s in self.history[pid] if 0 <= (now-s.at).total_seconds() <= 5]
                  for pid in CORE}
        speeds = recent[0x0D]
        if (len(speeds) < 3 or any(not s.valid for s in speeds)
                or any((b.at-a.at).total_seconds() > 3 for a, b in zip(speeds, speeds[1:]))
                or (speeds[-1].at-speeds[0].at).total_seconds() < 1.5):
            return None
        xs = [(s.at-speeds[0].at).total_seconds() for s in speeds]
        ys = [s.value/3.6 for s in speeds]
        mx, my = sum(xs)/len(xs), sum(ys)/len(ys)
        variance = sum((x-mx)**2 for x in xs)
        if variance <= 0:
            return None
        slope = sum((x-mx)*(y-my) for x, y in zip(xs, ys))/variance

        def span(pid):
            values = [s.value for s in recent[pid] if s.valid]
            return max(values)-min(values)

        return [self.latest[pid].value for pid in CORE] + [slope, span(0x0D), span(0x0C), span(0x11)]
