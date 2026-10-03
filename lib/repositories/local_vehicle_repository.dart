import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:autopulse_ai/models/vehicle.dart';

/// Account-specific local vehicle selection survives restarts and works offline.
class LocalVehicleRepository {
  String _key(String? owner) => 'obd_vehicle_${owner ?? 'offline'}';

  Future<Vehicle?> load(String? owner) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(owner));
    if (raw == null) return null;
    final row = jsonDecode(raw) as Map<String, dynamic>;
    return Vehicle(
      id: row['id'],
      ownerId: owner,
      make: row['make'],
      model: row['model'],
      year: row['year'],
      vin: row['vin'],
    );
  }

  Future<Vehicle> save(Vehicle vehicle, String? owner) async {
    final previous = await load(owner);
    final same =
        previous != null &&
        previous.make == vehicle.make &&
        previous.model == vehicle.model &&
        previous.year == vehicle.year &&
        previous.vin == vehicle.vin;
    final saved = Vehicle(
      id: same ? previous.id : const Uuid().v4(),
      ownerId: owner,
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year,
      vin: vehicle.vin,
    );
    final preferences = await SharedPreferences.getInstance();
    final success = await preferences.setString(
      _key(owner),
      jsonEncode({
        'id': saved.id,
        'make': saved.make,
        'model': saved.model,
        'year': saved.year,
        'vin': saved.vin,
      }),
    );
    if (!success) throw StateError('Could not save vehicle selection.');
    return saved;
  }
}
