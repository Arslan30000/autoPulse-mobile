import 'package:autosense_ai/models/vehicle.dart';
import 'package:autosense_ai/data/mock/mock_data.dart';

abstract class VehicleService {
  Future<Vehicle> getVehicle();
  Future<Vehicle> connectOBD(Vehicle vehicle);
}

class MockVehicleService implements VehicleService {
  @override
  Future<Vehicle> getVehicle() async {
    return MockData.vehicle;
  }

  @override
  Future<Vehicle> connectOBD(Vehicle vehicle) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    return vehicle.copyWith(isConnected: true);
  }
}