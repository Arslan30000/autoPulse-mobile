import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:autopulse_ai/models/vehicle.dart';

/// Keeps the legacy selection key so existing installations retain their car.
class LocalVehicleRepository {
  static Future<dynamic>? _writes;
  Future<T> _write<T>(Future<T> Function() action) {
    final previous = _writes;
    late final Future<T> next;
    next =
        (previous == null
                ? action()
                : previous.then(
                    (_) => action(),
                    onError: (Object _, StackTrace _) => action(),
                  ))
            .whenComplete(() {
              if (identical(_writes, next)) _writes = null;
            });
    _writes = next;
    return next;
  }

  String _key(String? owner) => 'obd_vehicle_${owner ?? 'offline'}';
  static Map<String, dynamic> encode(Vehicle v) => {
    'id': v.id,
    'make': v.make,
    'model': v.model,
    'year': v.year,
    'vin': v.vin,
  };
  static Vehicle decode(Map<String, dynamic> row, String? owner) => Vehicle(
    id: row['id'] as String?,
    ownerId: owner,
    make: row['make'] as String,
    model: row['model'] as String,
    year: (row['year'] as num).toInt(),
    vin: row['vin'] as String?,
  );
  Future<Vehicle?> load(String? owner) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(owner));
    return raw == null
        ? null
        : decode(jsonDecode(raw) as Map<String, dynamic>, owner);
  }

  Future<List<Vehicle>> list(String? owner) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_key(owner)}_list');
    if (raw != null) {
      return (jsonDecode(raw) as List)
          .map((r) => decode(Map<String, dynamic>.from(r as Map), owner))
          .toList();
    }
    final legacy = await load(owner);
    return legacy == null ? [] : [legacy];
  }

  Future<void> select(Vehicle vehicle, String? owner) =>
      _write(() => _select(vehicle, owner));
  Future<void> _select(Vehicle vehicle, String? owner) async {
    if (vehicle.ownerId != owner) {
      throw StateError('Vehicle belongs to another account.');
    }
    if (!await (await SharedPreferences.getInstance()).setString(
      _key(owner),
      jsonEncode(encode(vehicle)),
    )) {
      throw StateError('Could not save vehicle selection.');
    }
  }

  Future<Vehicle> save(Vehicle vehicle, String? owner) => _write(() async {
    final previous = await load(owner);
    final same =
        previous != null &&
        previous.make == vehicle.make &&
        previous.model == vehicle.model &&
        previous.year == vehicle.year &&
        previous.vin == vehicle.vin;
    final saved = Vehicle(
      id: vehicle.id ?? (same ? previous.id : const Uuid().v4()),
      ownerId: owner,
      make: vehicle.make,
      model: vehicle.model,
      year: vehicle.year,
      vin: vehicle.vin,
    );
    final rows = await list(owner);
    final pendingIds = owner == null ? <String>[] : await _pendingIds(owner);
    rows.removeWhere((v) => v.id == saved.id);
    rows.add(saved);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      '${_key(owner)}_list',
      jsonEncode(rows.map(encode).toList()),
    )) {
      throw StateError('Could not save vehicles.');
    }
    if (owner != null) {
      final pending = pendingIds;
      if (!pending.contains(saved.id)) pending.add(saved.id!);
      if (!await prefs.setStringList('${_key(owner)}_pending', pending)) {
        throw StateError('Could not queue vehicle backup.');
      }
    }
    await _select(saved, owner);
    return saved;
  });

  Future<List<Vehicle>> pending(String owner) async {
    final ids = await _pendingIds(owner);
    return (await list(owner)).where((v) => ids.contains(v.id)).toList();
  }

  Future<List<String>> _pendingIds(String owner) async {
    final stored = (await SharedPreferences.getInstance()).getStringList(
      '${_key(owner)}_pending',
    );
    // Cars saved before this upgrade have no queue key; back them up once.
    return stored ?? (await list(owner)).map((v) => v.id!).toList();
  }

  Future<void> acknowledge(String owner, String id) => _write(() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _pendingIds(owner);
    ids.remove(id);
    if (!await prefs.setStringList('${_key(owner)}_pending', ids)) {
      throw StateError('Could not save backup status.');
    }
  });

  Future<void> mergeCloud(List<Vehicle> vehicles, String owner) =>
      _write(() async {
        final rows = await list(owner);
        final pendingIds = await _pendingIds(owner);
        final dirty = (await pending(owner)).map((v) => v.id).toSet();
        for (final v in vehicles) {
          if (dirty.contains(v.id)) continue;
          rows.removeWhere((local) => local.id == v.id);
          rows.add(v);
        }
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setStringList('${_key(owner)}_pending', pendingIds)) {
          throw StateError('Could not save backup queue.');
        }
        if (!await prefs.setString(
          '${_key(owner)}_list',
          jsonEncode(rows.map(encode).toList()),
        )) {
          throw StateError('Could not cache cloud vehicles.');
        }
        final selected = await load(owner);
        if (rows.isNotEmpty) {
          await _select(
            rows.firstWhere(
              (v) => v.id == selected?.id,
              orElse: () => rows.first,
            ),
            owner,
          );
        }
      });
}
