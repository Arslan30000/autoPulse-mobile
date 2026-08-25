class TelemetryData {
  final double rpm;
  final double speed;
  final double coolantTemperature;
  final double intakeTemperature;
  final double engineLoad;
  final double throttlePosition;
  final double maf;
  final DateTime timestamp;

  const TelemetryData({
    required this.rpm,
    required this.speed,
    required this.coolantTemperature,
    required this.intakeTemperature,
    required this.engineLoad,
    required this.throttlePosition,
    required this.maf,
    required this.timestamp,
  });

  TelemetryData copyWith({
    double? rpm,
    double? speed,
    double? coolantTemperature,
    double? intakeTemperature,
    double? engineLoad,
    double? throttlePosition,
    double? maf,
    DateTime? timestamp,
  }) {
    return TelemetryData(
      rpm: rpm ?? this.rpm,
      speed: speed ?? this.speed,
      coolantTemperature: coolantTemperature ?? this.coolantTemperature,
      intakeTemperature: intakeTemperature ?? this.intakeTemperature,
      engineLoad: engineLoad ?? this.engineLoad,
      throttlePosition: throttlePosition ?? this.throttlePosition,
      maf: maf ?? this.maf,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}