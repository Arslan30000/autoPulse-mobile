/// Operating context, not a mechanical diagnosis or a judgment of driver intent.
enum DrivingState {
  disconnected,
  reading,
  insufficient,
  engineOff,
  idling,
  cityCruising,
  highwayCruising,
  accelerating,
  aggressiveAcceleration,
  decelerating,
  heavyLoad;

  String get label => switch (this) {
    disconnected => 'Not connected',
    reading => 'Reading context',
    insufficient => 'Waiting for readings',
    engineOff => 'Engine off',
    idling => 'Idling',
    cityCruising => 'City Cruising',
    highwayCruising => 'Highway Cruising',
    accelerating => 'Accelerating',
    aggressiveAcceleration => 'Strong Acceleration',
    decelerating => 'Decelerating',
    heavyLoad => 'Heavy Load',
  };

  String get description => switch (this) {
    disconnected => 'Connect your OBD-II adapter to see live driving context.',
    reading => 'Building a short window of fresh vehicle readings.',
    insufficient =>
      'Some required readings are missing, invalid or out of date.',
    engineOff => 'The vehicle is stationary and the engine is not running.',
    idling => 'The engine is running while the vehicle is stationary.',
    cityCruising => 'Steady movement in a lower speed band.',
    highwayCruising => 'Steady movement in a higher speed band.',
    accelerating => 'Vehicle speed is increasing.',
    aggressiveAcceleration =>
      'Speed is increasing quickly with high engine demand.',
    decelerating => 'Vehicle speed is decreasing.',
    heavyLoad =>
      'Engine demand has increased. This alone does not confirm an incline.',
  };

  bool get isOperating => index >= engineOff.index;
  bool get significant => switch (this) {
    heavyLoad || aggressiveAcceleration || decelerating => true,
    _ => false,
  };
}

enum ContextSource { rules, model, experimentalModel }

class DrivingContextSnapshot {
  const DrivingContextSnapshot({
    required this.state,
    this.highDemand = false,
    this.source = ContextSource.rules,
    this.modelVersion,
    this.updatedAt,
  });
  final DrivingState state;
  final bool highDemand;
  final ContextSource source;
  final String? modelVersion;
  final DateTime? updatedAt;
}

class ContextNotice {
  const ContextNotice(this.revision, this.context);
  final int revision;
  final DrivingContextSnapshot context;
}
