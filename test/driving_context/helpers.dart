import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';

final contextEpoch = DateTime.utc(2026, 11, 10);
ObdSample contextSample(
  ObdParameter parameter,
  double? value,
  double second, {
  ObdSampleStatus status = ObdSampleStatus.valid,
}) {
  final at = contextEpoch.add(Duration(microseconds: (second * 1e6).round()));
  return ObdSample(
    parameter: parameter,
    value: value,
    status: status,
    requestedAt: at,
    receivedAt: at,
    latencyMs: 0,
  );
}

void frame(
  DrivingContextController controller,
  int second, {
  double speed = 40,
  double rpm = 1600,
  double load = 40,
  double throttle = 20,
}) {
  for (final entry in {
    ObdParameter.load: load,
    ObdParameter.throttle: throttle,
    ObdParameter.rpm: rpm,
    ObdParameter.speed: speed,
  }.entries) {
    controller.accept(contextSample(entry.key, entry.value, second.toDouble()));
  }
}
