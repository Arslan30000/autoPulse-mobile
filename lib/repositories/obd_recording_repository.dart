import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/services/account_service.dart';

enum RecordingSyncState { local, pending, uploading, synced, failed }

class ObdRecording {
  final int id;
  final String vehicleName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int sampleCount;
  final String cloudId;
  final Vehicle? vehicle;
  final String adapterName;
  final String? ownerId;
  final RecordingSyncState syncState;
  final int uploadedSampleId;
  final int uploadedSampleCount;
  final String? syncError;
  const ObdRecording({
    required this.id,
    required this.vehicleName,
    required this.startedAt,
    required this.endedAt,
    required this.sampleCount,
    this.cloudId = '',
    this.vehicle,
    this.adapterName = '',
    this.ownerId,
    this.syncState = RecordingSyncState.local,
    this.uploadedSampleId = 0,
    this.uploadedSampleCount = 0,
    this.syncError,
  });
}

class RecordedObdSample {
  final int id;
  final ObdSample sample;
  final String? storedUnit;
  String get unit => storedUnit ?? sample.parameter.unit;
  const RecordedObdSample(this.id, this.sample, {this.storedUnit});
}

abstract interface class ObdRecordingRepository {
  Future<int> start(Vehicle vehicle, ObdDevice device);
  Future<void> append(int sessionId, ObdSample sample);
  Future<void> finish(int sessionId);
  Future<List<ObdRecording>> recordings();
}

/// Additional read/sync API leaves the transport and controller independent.
abstract interface class RecordingStore implements ObdRecordingRepository {
  Future<List<ObdRecording>> listRecordings(
    String? owner, {
    int beforeId = 0,
    int limit = 50,
  });
  Future<ObdRecording> recording(int id);
  Future<List<RecordedObdSample>> samples(
    int sessionId, {
    int afterId = 0,
    int limit = 250,
  });
  Future<List<RecordedObdSample>> chartSamples(
    int sessionId,
    ObdParameter parameter, {
    int limit = 600,
    int beforeId = 0,
  });
  Future<ObdRecording> claimCompleted(int id, String owner);
  Future<void> setSyncState(
    int id,
    String owner,
    RecordingSyncState state, {
    String? error,
  });
  Future<void> checkpoint(int id, String owner, int sampleId);
  Future<void> close();
}

class SqliteObdRecordingRepository implements RecordingStore {
  final DatabaseFactory? factory;
  final String? databasePath;
  final String? Function() _owner;
  SqliteObdRecordingRepository({
    this.factory,
    this.databasePath,
    String? Function()? owner,
  }) : _owner = owner ?? (() => AccountService.instance.userId);
  Future<Database>? _database;
  Future<Database> get database => _database ??= _open();

  Future<Database> _open() async {
    try {
      final selected = factory ?? databaseFactory;
      return await selected.openDatabase(
        databasePath ??
            path.join(await selected.getDatabasesPath(), 'obd_recordings.db'),
        options: OpenDatabaseOptions(
          version: 2,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE sessions (
              id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle_name TEXT NOT NULL,
              vehicle_year INTEGER NOT NULL, adapter_name TEXT NOT NULL,
              started_at TEXT NOT NULL, ended_at TEXT)''');
            await db.execute('''CREATE TABLE samples (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER NOT NULL REFERENCES sessions(id),
              pid INTEGER NOT NULL, value REAL, unit TEXT NOT NULL, quality TEXT NOT NULL,
              requested_at TEXT NOT NULL, received_at TEXT NOT NULL,
              latency_ms INTEGER NOT NULL, ecu_source TEXT)''');
            await db.execute(
              'CREATE INDEX samples_session_time ON samples(session_id, received_at)',
            );
            await _upgrade(db);
          },
          onUpgrade: (db, oldVersion, _) async {
            if (oldVersion < 2) await _upgrade(db);
          },
        ),
      );
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  static Future<void> _upgrade(Database db) async {
    await db.execute('''CREATE TABLE local_vehicles (
      id TEXT PRIMARY KEY, owner_id TEXT, source_id TEXT NOT NULL)''');
    for (final column in [
      'cloud_id TEXT',
      'vehicle_id TEXT REFERENCES local_vehicles(id)',
      'owner_id TEXT',
      'vehicle_make TEXT',
      'vehicle_model TEXT',
      'vehicle_vin TEXT',
      "sync_state TEXT NOT NULL DEFAULT 'local'",
      'uploaded_sample_id INTEGER NOT NULL DEFAULT 0',
      'sync_error TEXT',
    ]) {
      await db.execute('ALTER TABLE sessions ADD COLUMN $column');
    }
    // Preserve v1 rows. Unknown make/model are explicit, never guessed from a label.
    for (final row in await db.query('sessions')) {
      final vehicleId = const Uuid().v4();
      await db.insert('local_vehicles', {
        'id': vehicleId,
        'source_id': vehicleId,
      });
      await db.update(
        'sessions',
        {
          'cloud_id': const Uuid().v4(),
          'vehicle_id': vehicleId,
          'vehicle_make': 'Unknown',
          'vehicle_model': row['vehicle_name'],
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await db.execute(
      'CREATE UNIQUE INDEX sessions_cloud_id ON sessions(cloud_id)',
    );
    await db.execute(
      'CREATE INDEX samples_session_id ON samples(session_id, id)',
    );
    await db.execute(
      "CREATE UNIQUE INDEX local_vehicle_source_owner ON local_vehicles(source_id, ifnull(owner_id, ''))",
    );
    await db.execute('CREATE INDEX sessions_owner ON sessions(owner_id, id)');
  }

  @override
  Future<int> start(Vehicle vehicle, ObdDevice device) async {
    if (vehicle.make.trim().isEmpty || vehicle.model.trim().isEmpty) {
      throw ArgumentError(
        'Select a vehicle with a make and model before recording.',
      );
    }
    final owner = _owner();
    if (vehicle.ownerId != null && vehicle.ownerId != owner) {
      throw StateError(
        'Select a vehicle for the current account before recording.',
      );
    }
    final sourceId = vehicle.id ?? const Uuid().v4();
    return (await database).transaction((tx) async {
      final existing = await tx.query(
        'local_vehicles',
        where: owner == null
            ? 'source_id = ? AND owner_id IS NULL'
            : 'source_id = ? AND owner_id = ?',
        whereArgs: [sourceId, ?owner],
      );
      String vehicleId;
      if (existing.isNotEmpty) {
        vehicleId = existing.single['id'] as String;
      } else {
        final original = await tx.query(
          'local_vehicles',
          where: 'id = ?',
          whereArgs: [sourceId],
        );
        vehicleId = original.isEmpty ? sourceId : const Uuid().v4();
        await tx.insert('local_vehicles', {
          'id': vehicleId,
          'owner_id': owner,
          'source_id': sourceId,
        });
      }
      return tx.insert('sessions', {
        'cloud_id': const Uuid().v4(),
        'vehicle_id': vehicleId,
        'owner_id': owner,
        'vehicle_name': vehicle.displayName,
        'vehicle_make': vehicle.make,
        'vehicle_model': vehicle.model,
        'vehicle_year': vehicle.year,
        'vehicle_vin': vehicle.vin,
        'adapter_name': device.name,
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  @override
  Future<void> append(int sessionId, ObdSample sample) async {
    if (sample.latencyMs < 0 ||
        (sample.status == ObdSampleStatus.valid
            ? sample.value == null || !sample.value!.isFinite
            : sample.value != null)) {
      throw ArgumentError('Measurement value and quality are inconsistent.');
    }
    await (await database).transaction((tx) async {
      final session = await tx.query(
        'sessions',
        columns: ['ended_at'],
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      if (session.isEmpty || session.single['ended_at'] != null) {
        throw StateError('Cannot append to a closed or missing recording.');
      }
      await tx.insert('samples', {
        'session_id': sessionId,
        'pid': sample.parameter.pid,
        'value': sample.value,
        'unit': sample.parameter.unit,
        'quality': sample.status.name,
        'requested_at': sample.requestedAt.toUtc().toIso8601String(),
        'received_at': sample.receivedAt.toUtc().toIso8601String(),
        'latency_ms': sample.latencyMs,
        'ecu_source': sample.source,
      });
    });
  }

  @override
  Future<void> finish(int sessionId) async {
    await (await database).update(
      'sessions',
      {'ended_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ? AND ended_at IS NULL',
      whereArgs: [sessionId],
    );
  }

  static const _select = '''SELECT s.*, (SELECT COUNT(*) FROM samples r
    WHERE r.session_id = s.id) AS sample_count,
    (SELECT COUNT(*) FROM samples r WHERE r.session_id = s.id
      AND r.id <= s.uploaded_sample_id) AS uploaded_sample_count FROM sessions s''';

  ObdRecording _recording(Map<String, Object?> row) => ObdRecording(
    id: row['id'] as int,
    vehicleName: row['vehicle_name'] as String,
    startedAt: DateTime.parse(row['started_at'] as String),
    endedAt: row['ended_at'] == null
        ? null
        : DateTime.parse(row['ended_at'] as String),
    sampleCount: row['sample_count'] as int,
    cloudId: row['cloud_id'] as String,
    adapterName: row['adapter_name'] as String,
    ownerId: row['owner_id'] as String?,
    syncState: RecordingSyncState.values.byName(row['sync_state'] as String),
    uploadedSampleId: row['uploaded_sample_id'] as int,
    uploadedSampleCount: row['uploaded_sample_count'] as int,
    syncError: row['sync_error'] as String?,
    vehicle: Vehicle(
      id: row['vehicle_id'] as String,
      ownerId: row['owner_id'] as String?,
      make: row['vehicle_make'] as String,
      model: row['vehicle_model'] as String,
      year: row['vehicle_year'] as int,
      vin: row['vehicle_vin'] as String?,
    ),
  );

  @override
  Future<List<ObdRecording>> recordings() => listRecordings(_owner());

  @override
  Future<List<ObdRecording>> listRecordings(
    String? owner, {
    int beforeId = 0,
    int limit = 50,
  }) async {
    _limit(limit);
    final rows = await (await database).rawQuery(
      '$_select WHERE ${owner == null ? 's.owner_id IS NULL' : '(s.owner_id IS NULL OR s.owner_id = ?)'} '
      'AND (? = 0 OR s.id < ?) ORDER BY s.id DESC LIMIT ?',
      [?owner, beforeId, beforeId, limit],
    );
    return rows.map(_recording).toList();
  }

  @override
  Future<ObdRecording> recording(int id) async {
    final rows = await (await database).rawQuery('$_select WHERE s.id = ?', [
      id,
    ]);
    if (rows.isEmpty) throw StateError('Recording no longer exists.');
    return _recording(rows.single);
  }

  RecordedObdSample _sample(Map<String, Object?> row) => RecordedObdSample(
    row['id'] as int,
    ObdSample(
      parameter: ObdParameter.values.firstWhere((p) => p.pid == row['pid']),
      value: (row['value'] as num?)?.toDouble(),
      status: ObdSampleStatus.values.byName(row['quality'] as String),
      requestedAt: DateTime.parse(row['requested_at'] as String),
      receivedAt: DateTime.parse(row['received_at'] as String),
      latencyMs: row['latency_ms'] as int,
      source: row['ecu_source'] as String?,
    ),
    storedUnit: row['unit'] as String,
  );

  void _limit(int limit) {
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Use a page size from 1 to 1000.',
      );
    }
  }

  @override
  Future<List<RecordedObdSample>> samples(
    int sessionId, {
    int afterId = 0,
    int limit = 250,
  }) async {
    _limit(limit);
    final rows = await (await database).query(
      'samples',
      where: 'session_id = ? AND id > ?',
      whereArgs: [sessionId, afterId],
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(_sample).toList();
  }

  @override
  Future<List<RecordedObdSample>> chartSamples(
    int sessionId,
    ObdParameter parameter, {
    int limit = 600,
    int beforeId = 0,
  }) async {
    _limit(limit);
    final rows = await (await database).query(
      'samples',
      where: 'session_id = ? AND pid = ? ${beforeId == 0 ? '' : 'AND id < ?'}',
      whereArgs: [sessionId, parameter.pid, if (beforeId != 0) beforeId],
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.reversed.map(_sample).toList();
  }

  @override
  Future<ObdRecording> claimCompleted(int id, String owner) async {
    if (owner.isEmpty) {
      throw ArgumentError('An authenticated owner is required.');
    }
    await (await database).transaction((tx) async {
      final rows = await tx.query('sessions', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty || rows.single['ended_at'] == null) {
        throw StateError('Only finished recordings can be uploaded.');
      }
      final row = rows.single;
      if (row['owner_id'] != null && row['owner_id'] != owner) {
        throw StateError('Recording belongs to another account.');
      }
      final vehicles = await tx.query(
        'local_vehicles',
        where: 'id = ?',
        whereArgs: [row['vehicle_id']],
      );
      if (vehicles.single['owner_id'] != null &&
          vehicles.single['owner_id'] != owner) {
        throw StateError('This vehicle was assigned to another account.');
      }
      final sameOwner = await tx.query(
        'local_vehicles',
        where: 'source_id = ? AND owner_id = ?',
        whereArgs: [vehicles.single['source_id'], owner],
      );
      final targetVehicle = sameOwner.isEmpty
          ? row['vehicle_id']
          : sameOwner.single['id'];
      if (sameOwner.isEmpty) {
        await tx.update(
          'local_vehicles',
          {'owner_id': owner},
          where: 'id = ?',
          whereArgs: [row['vehicle_id']],
        );
      }
      await tx.update(
        'sessions',
        {
          'owner_id': owner,
          'vehicle_id': targetVehicle,
          'sync_state': row['sync_state'] == 'synced' ? 'synced' : 'pending',
          'sync_error': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    return recording(id);
  }

  @override
  Future<void> setSyncState(
    int id,
    String owner,
    RecordingSyncState state, {
    String? error,
  }) async {
    final count = await (await database).update(
      'sessions',
      {'sync_state': state.name, 'sync_error': error},
      where: 'id = ? AND owner_id = ? AND ended_at IS NOT NULL',
      whereArgs: [id, owner],
    );
    if (count != 1) throw StateError('Recording ownership changed.');
  }

  @override
  Future<void> checkpoint(int id, String owner, int sampleId) async {
    final count = await (await database).update(
      'sessions',
      {'uploaded_sample_id': sampleId},
      where:
          'id = ? AND owner_id = ? AND uploaded_sample_id <= ? '
          'AND EXISTS (SELECT 1 FROM samples WHERE session_id = ? AND id = ?)',
      whereArgs: [id, owner, sampleId, id, sampleId],
    );
    if (count != 1) throw StateError('Invalid upload checkpoint.');
  }

  @override
  Future<void> close() async {
    final pending = _database;
    if (pending != null) await (await pending).close();
    _database = null;
  }
}
