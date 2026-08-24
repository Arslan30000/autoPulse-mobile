import 'dart:async';
import 'dart:math';
import 'package:autosense_ai/models/telemetry.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';

abstract class TelemetryService {
  Stream<TelemetryData> getTelemetryStream();
  Future<TelemetryData> getCurrentTelemetry();
}

class MockTelemetryService implements TelemetryService {
  final _random = Random();

  @override
  Stream<TelemetryData> getTelemetryStream() {
    return Stream.periodic(const Duration(seconds: 2), (_) {
      return _generateTelemetry();
    });
  }

  @override
  Future<TelemetryData> getCurrentTelemetry() async {
    return MockData.currentTelemetry;
  }

  TelemetryData _generateTelemetry() {
    final base = MockData.currentTelemetry;
    return base.copyWith(
      rpm: base.rpm + (_random.nextDouble() * 60 - 30),
      coolantTemperature: base.coolantTemperature + (_random.nextDouble() * 2 - 1),
      intakeTemperature: base.intakeTemperature + (_random.nextDouble() * 2 - 1),
      engineLoad: base.engineLoad + (_random.nextDouble() * 3 - 1.5),
      throttlePosition: base.throttlePosition + (_random.nextDouble() * 2 - 1),
      maf: base.maf + (_random.nextDouble() * 0.04 - 0.02),
      timestamp: DateTime.now(),
    );
  }
}
