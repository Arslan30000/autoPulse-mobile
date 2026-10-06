import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';

// Synthetic fixtures only. Never inserted by production application code.
const fixtureVehicle = Vehicle(make: 'Synthetic', model: 'Fixture', year: 2020);
const fixtureDevice = ObdDevice(name: 'Synthetic adapter', address: 'test');
ObdSample fixtureSample(
  int index, {
  ObdParameter parameter = ObdParameter.rpm,
  ObdSampleStatus status = ObdSampleStatus.valid,
}) {
  final time = DateTime.utc(2026, 1, 1).add(Duration(seconds: index));
  return ObdSample(
    parameter: parameter,
    value: status == ObdSampleStatus.valid ? 1000.0 + index : null,
    status: status,
    requestedAt: time,
    receivedAt: time.add(const Duration(milliseconds: 100)),
    latencyMs: 100,
    source: '7E8',
  );
}
