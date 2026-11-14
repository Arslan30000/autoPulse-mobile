import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/services/account_service.dart';

enum RecordingSyncState { local, pending, uploading, synced, failed }

enum RecordingSortField { date, duration }

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
  Duration? get duration {
    final end = endedAt;
    return end == null || end.isBefore(startedAt)
        ? null
        : end.difference(startedAt);
  }

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
    RecordingSortField sortBy = RecordingSortField.date,
    bool ascending = false,
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
          version: 3,
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
            await _createRestoreStaging(db);
          },
          onUpgrade: (db, oldVersion, _) async {
            if (oldVersion < 2) await _upgrade(db);
            if (oldVersion < 3) await _createRestoreStaging(db);
          },
        ),
      );
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  static Future<void> _createRestoreStaging(Database db) async {
    await db.execute(
      '''CREATE TABLE restore_jobs (
      cloud_id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, expected_count INTEGER NOT NULL)''',
    );
    await db.execute('''CREATE TABLE restore_samples (
      cloud_id TEXT NOT NULL REFERENCES restore_jobs(cloud_id) ON DELETE CASCADE,
      sample_id INTEGER NOT NULL, pid INTEGER NOT NULL, value REAL,
      unit TEXT NOT NULL, quality TEXT NOT NULL, requested_at TEXT NOT NULL,
      received_at TEXT NOT NULL, latency_ms INTEGER NOT NULL, ecu_source TEXT,
      PRIMARY KEY(cloud_id,sample_id))''');
  }

  /// Called once at process startup, before recording or sync begins. A process
  /// kill cannot run finish(); close its durable prefix at the last saved time.
  Future<void> recoverInterruptedRecordings() async {
    await (await database).rawUpdate('''UPDATE sessions SET ended_at =
      max(started_at,coalesce((SELECT max(received_at) FROM samples
        WHERE samples.session_id = sessions.id),started_at)),
      sync_state = CASE WHEN owner_id IS NULL THEN 'local' ELSE 'pending' END
      WHERE ended_at IS NULL''');
  }

  Future<int> restoreCursor(Map<String, dynamic> session, String owner) async {
    if (_owner() != owner ||
        session['owner_id'] != owner ||
        session['uploaded_at'] == null) {
      throw StateError('Cloud recording is unavailable.');
    }
    final db = await database;
    final existing = await db.query(
      'restore_jobs',
      where: 'cloud_id = ?',
      whereArgs: [session['id']],
    );
    if (existing.isNotEmpty &&
        (existing.single['owner_id'] != owner ||
            existing.single['expected_count'] != session['sample_count'])) {
      throw StateError('Cloud recording changed during restore.');
    }
    await db.insert('restore_jobs', {
      'cloud_id': session['id'],
      'owner_id': owner,
      'expected_count': session['sample_count'],
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await db.rawQuery(
      'SELECT MAX(sample_id) AS cursor FROM restore_samples WHERE cloud_id = ?',
      [session['id']],
    );
    return rows.single['cursor'] as int? ?? 0;
  }

  /// Start an explicit restore retry at zero. This clears only hidden staging;
  /// published phone recordings and all cloud data remain untouched.
  Future<void> restartRestore(
    Map<String, dynamic> session,
    String owner,
  ) async {
    if (_owner() != owner || session['owner_id'] != owner) {
      throw StateError('Cloud recording is unavailable.');
    }
    await (await database).delete(
      'restore_jobs',
      where: 'cloud_id = ? AND owner_id = ?',
      whereArgs: [session['id'], owner],
    );
    await restoreCursor(session, owner);
  }

  /// Durable staging checkpoints survive a download interruption. Partial trips
  /// stay hidden; only a verified complete trip is promoted to visible history.
  Future<void> importCloudPages(
    Map<String, dynamic> session,
    Vehicle vehicle,
    Stream<List<Map<String, dynamic>>> pages,
    String owner, {
    void Function(int restored, int total)? onProgress,
  }) async {
    var cursor = await restoreCursor(session, owner);
    if (vehicle.ownerId != owner) {
      throw StateError('Vehicle ownership differs.');
    }
    final db = await database;
    var restored =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM restore_samples WHERE cloud_id = ?',
            [session['id']],
          ),
        ) ??
        0;
    final total = (session['sample_count'] as num).toInt();
    onProgress?.call(restored, total);
    await for (final rows in pages) {
      if (_owner() != owner) {
        throw StateError('Account changed during restore.');
      }
      if (rows.length > 1000) throw StateError('Restore page is too large.');
      var inserted = 0;
      await db.transaction((tx) async {
        final batch = tx.batch();
        final pageIds = <int>{};
        for (final row in rows) {
          final id = row['sample_id'] as int;
          if (row['session_id'] != session['id'] || row['owner_id'] != owner) {
            throw StateError('Invalid restored sample identity.');
          }
          if (!pageIds.add(id)) {
            throw StateError('Duplicate restored sample identity.');
          }
          // A resumed download can replay a page after its previous response
          // was lost. Its rows are already in durable staging; only advance
          // from new sample IDs. The final exact-count check still guards gaps.
          if (id <= cursor) continue;
          final value = (row['value'] as num?)?.toDouble();
          final quality = ObdSampleStatus.values.byName(
            row['quality'] as String,
          );
          if ((quality == ObdSampleStatus.valid
                  ? value == null || !value.isFinite
                  : value != null) ||
              (row['latency_ms'] as num) < 0 ||
              !ObdParameter.values.any((p) => p.pid == row['pid']) ||
              (row['unit'] as String).length > 40 ||
              ((row['ecu_source'] as String?)?.length ?? 0) > 100) {
            throw StateError('Invalid restored measurement.');
          }
          DateTime.parse(row['requested_at'] as String);
          DateTime.parse(row['received_at'] as String);
          batch.insert('restore_samples', {
            'cloud_id': session['id'],
            'sample_id': id,
            'pid': row['pid'],
            'value': value,
            'unit': row['unit'],
            'quality': quality.name,
            'requested_at': row['requested_at'],
            'received_at': row['received_at'],
            'latency_ms': row['latency_ms'],
            'ecu_source': row['ecu_source'],
          });
          cursor = id;
          inserted++;
        }
        await batch.commit(noResult: true);
        if (_owner() != owner) {
          throw StateError('Account changed during restore.');
        }
      });
      restored += inserted;
      onProgress?.call(restored, total);
    }
    await db.transaction((tx) async {
      if (_owner() != owner) {
        throw StateError('Account changed during restore.');
      }
      final count = Sqflite.firstIntValue(
        await tx.rawQuery(
          'SELECT COUNT(*) FROM restore_samples WHERE cloud_id = ?',
          [session['id']],
        ),
      );
      if (count != session['sample_count']) {
        throw StateError(
          'Cloud restore received $count of ${session['sample_count']} samples.',
        );
      }
      final existing = await tx.query(
        'sessions',
        where: 'cloud_id = ?',
        whereArgs: [session['id']],
      );
      if (existing.isNotEmpty) {
        if (existing.single['owner_id'] != owner) {
          throw StateError('Recording belongs to another account.');
        }
        await tx.delete(
          'restore_jobs',
          where: 'cloud_id = ?',
          whereArgs: [session['id']],
        );
        return;
      }
      await tx.insert('local_vehicles', {
        'id': vehicle.id,
        'source_id': vehicle.id,
        'owner_id': owner,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final car = await tx.query(
        'local_vehicles',
        where: 'id = ? AND owner_id = ?',
        whereArgs: [vehicle.id, owner],
      );
      if (car.isEmpty) {
        throw StateError('Vehicle identity belongs to another account.');
      }
      final id = await tx.insert('sessions', {
        'cloud_id': session['id'],
        'owner_id': owner,
        'vehicle_id': vehicle.id,
        'vehicle_name': session['vehicle_name'],
        'vehicle_make': vehicle.make,
        'vehicle_model': vehicle.model,
        'vehicle_year': vehicle.year,
        'vehicle_vin': vehicle.vin,
        'adapter_name': session['adapter_name'],
        'started_at': session['started_at'],
        'ended_at': session['ended_at'],
        'sync_state': 'synced',
      });
      await tx.rawInsert(
        '''INSERT INTO samples(session_id,pid,value,unit,quality,requested_at,received_at,latency_ms,ecu_source)
        SELECT ?,pid,value,unit,quality,requested_at,received_at,latency_ms,ecu_source
        FROM restore_samples WHERE cloud_id = ? ORDER BY sample_id''',
        [id, session['id']],
      );
      final last =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT MAX(id) FROM samples WHERE session_id = ?',
              [id],
            ),
          ) ??
          0;
      await tx.update(
        'sessions',
        {'uploaded_sample_id': last},
        where: 'id = ?',
        whereArgs: [id],
      );
      await tx.delete(
        'restore_jobs',
        where: 'cloud_id = ?',
        whereArgs: [session['id']],
      );
      if (_owner() != owner) {
        throw StateError('Account changed during restore.');
      }
    });
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

  /// Restore only complete uploads, atomically, without replacing local runs.
  Future<void> importCloud(
    Map<String, dynamic> session,
    Vehicle vehicle,
    List<Map<String, dynamic>> rows,
    String owner,
  ) async {
    if (_owner() != owner ||
        session['owner_id'] != owner ||
        vehicle.ownerId != owner) {
      throw StateError('Account changed during restore.');
    }
    if (session['uploaded_at'] == null ||
        rows.length != session['sample_count'] ||
        rows.any(
          (r) => r['owner_id'] != owner || r['session_id'] != session['id'],
        )) {
      throw StateError('Cloud recording is incomplete.');
    }
    // Local sample IDs determine graph/export order. Preserve acquisition order
    // even when a downloaded payload arrives in a different order.
    final orderedRows = List<Map<String, dynamic>>.of(
      rows,
    )..sort((a, b) => (a['sample_id'] as num).compareTo(b['sample_id'] as num));
    await (await database).transaction((tx) async {
      if (_owner() != owner) {
        throw StateError('Account changed during restore.');
      }
      final existing = await tx.query(
        'sessions',
        where: 'cloud_id = ?',
        whereArgs: [session['id']],
      );
      if (existing.isNotEmpty) {
        if (existing.single['owner_id'] != owner) {
          throw StateError('Recording belongs to another account.');
        }
        return;
      }
      await tx.insert('local_vehicles', {
        'id': vehicle.id,
        'source_id': vehicle.id,
        'owner_id': owner,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final localVehicle = await tx.query(
        'local_vehicles',
        where: 'id = ? AND owner_id = ?',
        whereArgs: [vehicle.id, owner],
      );
      if (localVehicle.isEmpty) {
        throw StateError('Vehicle identity belongs to another account.');
      }
      final id = await tx.insert('sessions', {
        'cloud_id': session['id'],
        'owner_id': owner,
        'vehicle_id': vehicle.id,
        'vehicle_name': session['vehicle_name'],
        'vehicle_make': vehicle.make,
        'vehicle_model': vehicle.model,
        'vehicle_year': vehicle.year,
        'vehicle_vin': vehicle.vin,
        'adapter_name': session['adapter_name'],
        'started_at': session['started_at'],
        'ended_at': session['ended_at'],
        'sync_state': 'synced',
      });
      var batch = tx.batch();
      for (var i = 0; i < orderedRows.length; i++) {
        final r = orderedRows[i];
        batch.insert('samples', {
          'session_id': id,
          'pid': r['pid'],
          'value': r['value'],
          'unit': r['unit'],
          'quality': r['quality'],
          'requested_at': r['requested_at'],
          'received_at': r['received_at'],
          'latency_ms': r['latency_ms'],
          'ecu_source': r['ecu_source'],
        });
        if ((i + 1) % 250 == 0) {
          await batch.commit(noResult: true);
          batch = tx.batch();
        }
      }
      await batch.commit(noResult: true);
      final last = await tx.rawQuery(
        'SELECT MAX(id) AS last_id FROM samples WHERE session_id = ?',
        [id],
      );
      await tx.update(
        'sessions',
        {'uploaded_sample_id': last.single['last_id'] ?? 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (_owner() != owner) {
        throw StateError('Account changed during restore.');
      }
    });
  }

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
    RecordingSortField sortBy = RecordingSortField.date,
    bool ascending = false,
  }) async {
    _limit(limit);
    final visibility = owner == null
        ? 's.owner_id IS NULL'
        : '(s.owner_id IS NULL OR s.owner_id = ?)';
    final ownerArguments = <Object?>[?owner];
    // Compare actual instants, including restored timestamps with UTC offsets.
    // Unknown/invalid durations stay last in either direction, without guessing.
    final key = switch (sortBy) {
      RecordingSortField.date => 'julianday(s.started_at)',
      RecordingSortField.duration =>
        '''CASE
        WHEN julianday(s.ended_at) >= julianday(s.started_at)
        THEN ROUND((julianday(s.ended_at) - julianday(s.started_at)) * 86400000)
        ELSE NULL END''',
    };
    final direction = ascending ? 'ASC' : 'DESC';
    final comparison = ascending ? '>' : '<';
    // beforeId identifies the previous page's final row, not an ID cutoff.
    // Keep the anchor lookup and page query in one consistent read transaction.
    return (await database).transaction((tx) async {
      var afterCursor = '';
      final arguments = [...ownerArguments];
      if (beforeId != 0) {
        final anchor = await tx.rawQuery(
          'SELECT $key AS sort_key FROM sessions s WHERE $visibility AND s.id = ?',
          [...ownerArguments, beforeId],
        );
        if (anchor.isEmpty) return <ObdRecording>[];
        final value = anchor.single['sort_key'];
        if (value == null) {
          afterCursor = 'AND ($key) IS NULL AND s.id $comparison ?';
          arguments.add(beforeId);
        } else {
          afterCursor =
              'AND (($key) IS NULL OR ($key) $comparison ? '
              'OR (($key) = ? AND s.id $comparison ?))';
          arguments.addAll([value, value, beforeId]);
        }
      }
      arguments.add(limit);
      final rows = await tx.rawQuery(
        '$_select WHERE $visibility $afterCursor '
        'ORDER BY (($key) IS NULL) ASC, ($key) $direction, s.id $direction LIMIT ?',
        arguments,
      );
      return rows.map(_recording).toList();
    });
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

  /// Only already-owned active sessions can be backed up incrementally. Offline
  /// sessions keep their existing explicit ownership confirmation after stopping.
  Future<ObdRecording> claimForBackup(int id, String owner) async {
    final run = await recording(id);
    if (run.endedAt != null) return claimCompleted(id, owner);
    if (_owner() != owner || run.ownerId != owner) {
      throw StateError('Recording belongs to another account.');
    }
    final count = await (await database).update(
      'sessions',
      {'sync_state': 'pending', 'sync_error': null},
      where: 'id = ? AND owner_id = ? AND ended_at IS NULL',
      whereArgs: [id, owner],
    );
    if (count != 1) return claimCompleted(id, owner);
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
      where:
          'id = ? AND owner_id = ? ${state == RecordingSyncState.synced ? 'AND ended_at IS NOT NULL' : ''}',
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
