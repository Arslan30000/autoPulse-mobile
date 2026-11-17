"""Transparent provisional rules. Outputs are estimates, NOT training labels."""


def evaluate(values, previous="reading"):
    speed, rpm, load, throttle, acceleration, *_ = values
    if speed <= (2 if previous == "idling" else 1):
        return "engineOff" if rpm < 200 else "idling"
    if rpm < 200:
        return "insufficient"
    if acceleration <= (-.35 if previous == "decelerating" else -.55):
        return "decelerating"
    if acceleration >= (1.2 if previous == "aggressiveAcceleration" else 1.5) and load >= 60 and throttle >= 25:
        return "aggressiveAcceleration"
    if acceleration >= (.15 if previous == "accelerating" else .25):
        return "accelerating"
    if load >= (72 if previous == "heavyLoad" else 80):
        return "heavyLoad"
    return "highwayCruising" if speed >= (75 if previous == "highwayCruising" else 80) else "cityCruising"


class Stabilizer:
    """Replay counterpart of the Dart controller, with no wall-clock dependence."""
    def __init__(self):
        self.state = "reading"
        self.demand = False
        self.pending = None
        self.pending_at = self.last_speed = self.last_load = self.last_notice = None
        self.load_evidence = 0
        self.first_attempt = None

    def step(self, buffer, now, fresh=True, predictor=None):
        self.first_attempt = self.first_attempt or now
        values = buffer.extract(now)
        if values is None:
            self.pending = None
            self.load_evidence = 0
            if self.state != "reading" or self.last_speed is not None or (now-self.first_attempt).total_seconds() >= 10:
                self.state, self.demand = "insufficient", False
            return None
        speed_at, load_at = buffer.latest[0x0D].at, buffer.latest[0x04].at
        if not fresh or (self.last_speed is not None and speed_at <= self.last_speed):
            return None
        self.last_speed = speed_at
        state = predictor(values, self.state) if predictor else evaluate(values, self.state)
        if state == "insufficient":
            self.state, self.demand, self.pending = state, False, None
            return None
        demand = values[0] > 1 and values[2] >= (72 if self.demand else 80)
        if (state, demand) == (self.state, self.demand):
            self.pending = None
            return None
        if self.pending != (state, demand):
            self.pending = (state, demand)
            self.pending_at, self.last_load, self.load_evidence = speed_at, load_at, 1
            return None
        if load_at != self.last_load:
            self.last_load = load_at
            self.load_evidence += 1
        if ((speed_at-self.pending_at).total_seconds() < (5 if demand else 2)
                or (demand and self.load_evidence < 2)):
            return None
        old = self.state
        new_demand = demand and not self.demand
        self.state, self.demand, self.pending = state, demand, None
        significant = state in ("heavyLoad", "aggressiveAcceleration", "decelerating")
        if (old not in ("reading", "insufficient") and ((old != state and significant) or new_demand)
                and (self.last_notice is None or (now-self.last_notice).total_seconds() >= 25)):
            self.last_notice = now
            return "heavyLoad" if new_demand and not significant else state
        return None
