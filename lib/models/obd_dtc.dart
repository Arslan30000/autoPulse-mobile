enum DtcKind {
  stored('03', 0x43, 'Stored'),
  pending('07', 0x47, 'Pending'),
  permanent('0A', 0x4A, 'Permanent');

  const DtcKind(this.command, this.response, this.label);
  final String command;
  final int response;
  final String label;

  String get explanation => switch (this) {
    stored => 'Confirmed codes retained by the ECU.',
    pending => 'Potential faults awaiting confirmation by the ECU.',
    permanent => 'Emissions codes retained until the ECU verifies repair.',
  };
}

class ObdDtc {
  const ObdDtc({
    required this.code,
    required this.kind,
    required this.source,
    required this.readAt,
  });
  final String code;
  final DtcKind kind;
  final String source;
  final DateTime readAt;
  String get identity => '$source:$code';
  String get description =>
      _definitions[code] ??
      'Definition not bundled. Consult the service information for this vehicle.';

  // A small offline glossary, not a diagnosis or a replacement for OEM data.
  static const _definitions = {
    'P0100': 'Mass or volume air flow circuit',
    'P0101': 'Mass or volume air flow circuit range/performance',
    'P0115': 'Engine coolant temperature circuit',
    'P0133': 'Oxygen sensor circuit slow response (bank 1, sensor 1)',
    'P0171': 'System too lean (bank 1)',
    'P0172': 'System too rich (bank 1)',
    'P0300': 'Random/multiple cylinder misfire detected',
    'P0301': 'Cylinder 1 misfire detected',
    'P0302': 'Cylinder 2 misfire detected',
    'P0303': 'Cylinder 3 misfire detected',
    'P0304': 'Cylinder 4 misfire detected',
    'P0420': 'Catalyst system efficiency below threshold (bank 1)',
    'P0430': 'Catalyst system efficiency below threshold (bank 2)',
  };
}
