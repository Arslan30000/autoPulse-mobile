import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';

class ObdRecording {
  final int id;
  final String vehicleName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int sampleCount;
  const ObdRecording({
    required this.id,
    required this.vehicleName,
    required this.startedAt,
    required this.endedAt,
    required this.sampleCount,
  });
}

abstract interface class ObdRecordingRepository {
  Future<int> start(Vehicle vehicle, ObdDevice device);
  Future<void> append(int sessionId, ObdSample sample);
  Future<void> finish(int sessionId);
  Future<List<ObdRecording>> recordings();
}

class SqliteObdRecordingRepository implements ObdRecordingRepository {
  Future<Database>? _database;
  Future<Database> get database => _database ??= _open();

  Future<Database> _open() async {
    try {
      return await openDatabase(
        path.join(await getDatabasesPath(), 'obd_recordings.db'),
        version: 1,
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
        },
      );
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  @override
  Future<int> start(Vehicle vehicle, ObdDevice device) async =>
      (await database).insert('sessions', {
        'vehicle_name': vehicle.displayName,
        'vehicle_year': vehicle.year,
        'adapter_name': device.name,
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });
  @override
  Future<void> append(int sessionId, ObdSample sample) async {
    await (await database).insert('samples', {
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
  }

  @override
  Future<void> finish(int sessionId) async {
    await (await database).update(
      'sessions',
      {'ended_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<List<ObdRecording>> recordings() async {
    final rows = await (await database).rawQuery(
      '''SELECT s.*, COUNT(r.id) AS sample_count
      FROM sessions s LEFT JOIN samples r ON r.session_id = s.id
      GROUP BY s.id ORDER BY s.id DESC LIMIT 50''',
    );
    return rows
        .map(
          (row) => ObdRecording(
            id: row['id'] as int,
            vehicleName: row['vehicle_name'] as String,
            startedAt: DateTime.parse(row['started_at'] as String),
            endedAt: row['ended_at'] == null
                ? null
                : DateTime.parse(row['ended_at'] as String),
            sampleCount: row['sample_count'] as int,
          ),
        )
        .toList();
  }
}
