# Packaged driving-context models

`context-weak-yaris-v1-forest-40-depth6.json` is trained on the existing real Yaris
recordings using conservative telemetry-derived labels. It is **experimental**,
not independently reviewed, and has no established real-world accuracy. The
registry explicitly opts into this model; the app labels it as model + rules.
Idle/engine-off, unobserved classes and low forest votes use physical-rule fallbacks.

See `ml/driving_context/README.md` and `docs/ml/yaris-weak-label-experiment.md` for
training support, held-out comparisons and limits. Keep future model versions
separate. Never place training data, synthetic test artifacts or credentials here.
