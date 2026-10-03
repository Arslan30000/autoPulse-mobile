enum ObdConnectionStatus {
  disconnected,
  connecting,
  initializing,
  ready,
  error,
}

enum ObdSampleStatus { valid, unsupported, noData, invalid, timeout }

class ObdDevice {
  final String name;
  final String address;
  const ObdDevice({required this.name, required this.address});
}

enum ObdParameter {
  rpm(0x0C, 'Engine RPM', 'rpm', 2, 0),
  speed(0x0D, 'Vehicle speed', 'km/h', 1, 0),
  coolant(0x05, 'Coolant temperature', 'C', 1, 0),
  intake(0x0F, 'Intake temperature', 'C', 1, 0),
  load(0x04, 'Engine load', '%', 1, 1),
  throttle(0x11, 'Throttle position', '%', 1, 1),
  maf(0x10, 'Mass airflow', 'g/s', 2, 2),
  map(0x0B, 'Manifold pressure', 'kPa', 1, 0),
  shortTrim(0x06, 'Short fuel trim B1', '%', 1, 1),
  longTrim(0x07, 'Long fuel trim B1', '%', 1, 1);

  final int pid;
  final String label;
  final String unit;
  final int byteCount;
  final int decimals;
  const ObdParameter(
    this.pid,
    this.label,
    this.unit,
    this.byteCount,
    this.decimals,
  );
  String get pidHex => pid.toRadixString(16).padLeft(2, '0').toUpperCase();
  String get command => '01$pidHex';
}

/// One PID measurement, not a fabricated simultaneous multi-sensor snapshot.
class ObdSample {
  final ObdParameter parameter;
  final double? value;
  final ObdSampleStatus status;
  final DateTime requestedAt;
  final DateTime receivedAt;
  final int latencyMs;
  final String? source;
  const ObdSample({
    required this.parameter,
    required this.value,
    required this.status,
    required this.requestedAt,
    required this.receivedAt,
    required this.latencyMs,
    this.source,
  });
}
