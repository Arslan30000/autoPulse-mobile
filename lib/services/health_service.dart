import 'package:autosense_ai/models/health.dart';
import 'package:autosense_ai/models/health_event.dart';
import 'package:autosense_ai/models/drive_report.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';

abstract class HealthService {
  Future<VehicleHealth> getVehicleHealth();
  Future<List<HealthEvent>> getHealthHistory();
  Future<DriveReport> getDriveReport();
}

class MockHealthService implements HealthService {
  @override
  Future<VehicleHealth> getVehicleHealth() async {
    return MockData.vehicleHealth;
  }

  @override
  Future<List<HealthEvent>> getHealthHistory() async {
    return MockData.healthHistory;
  }

  @override
  Future<DriveReport> getDriveReport() async {
    return MockData.driveReport;
  }
}