import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_chunk_codec.dart';

abstract interface class CloudRecordingRepository {
  String? get ownerId;
  Future<void> prepare(ObdRecording recording, String owner);
  Future<void> upload(
    ObdRecording recording,
    String owner,
    List<RecordedObdSample> samples,
  );
  Future<void> complete(ObdRecording recording, String owner);
}

class SupabaseRecordingRepository implements CloudRecordingRepository {
  final SupabaseClient client;
  final String? Function()? accountOwner;
  final bool compressed;
  final _formats = <String, String>{};
  SupabaseRecordingRepository(
    this.client, {
    this.accountOwner,
    this.compressed = false,
  });
  @override
  String? get ownerId =>
      accountOwner != null ? accountOwner!() : client.auth.currentUser?.id;

  void _check(String owner) {
    if (ownerId != owner) {
      throw StateError('Sign in to the recording owner account.');
    }
  }

  /// Both formats stream bounded pages. Never load an entire long trip into RAM.
  Stream<List<Map<String, dynamic>>> samplePages(
    Map<String, dynamic> run,
    String owner, {
    int afterId = 0,
  }) async* {
    final sessionId = run['id'] as String;
    var cursor = afterId;
    if (run['storage_format'] == 'gzip-json-v1') {
      while (true) {
        _check(owner);
        final chunks = await client
            .from('obd_recording_chunks')
            .select()
            .eq('session_id', sessionId)
            .eq('owner_id', owner)
            .gt('last_sample_id', cursor)
            .order('first_sample_id', ascending: true)
            .limit(1)
            .timeout(const Duration(seconds: 25));
        _check(owner);
        if (chunks.isEmpty) return;
        final chunk = chunks.single;
        if (chunk['previous_sample_id'] != cursor) {
          throw StateError('Recording chunk chain is incomplete.');
        }
        final bytes = await client.storage
            .from('obd-recordings')
            .download(chunk['object_path'] as String)
            .timeout(const Duration(seconds: 30));
        _check(owner);
        if (bytes.length != chunk['byte_count']) {
          throw StateError('Recording object size differs.');
        }
        final rows = await RecordingChunkCodec.decodeAsync(
          bytes,
          expectedChecksum: chunk['sha256'] as String,
          expectedRows: (chunk['sample_count'] as num).toInt(),
        );
        var previous = cursor;
        for (final row in rows) {
          final id = row['sample_id'] as int;
          if (id <= previous ||
              row['owner_id'] != owner ||
              row['session_id'] != sessionId) {
            throw StateError(
              'Recording chunk contains invalid ownership or sample order.',
            );
          }
          previous = id;
        }
        if (rows.first['sample_id'] != chunk['first_sample_id'] ||
            rows.last['sample_id'] != chunk['last_sample_id']) {
          throw StateError('Recording chunk range differs.');
        }
        cursor = previous;
        yield rows;
      }
    }
    while (true) {
      _check(owner);
      final rows = await client
          .from('obd_recording_samples')
          .select()
          .eq('owner_id', owner)
          .eq('session_id', sessionId)
          .gt('sample_id', cursor)
          .order('sample_id', ascending: true)
          .limit(500)
          .timeout(const Duration(seconds: 25));
      _check(owner);
      if (rows.isEmpty) return;
      final next = (rows.last['sample_id'] as num).toInt();
      if (next <= cursor) {
        throw StateError('Cloud sample cursor did not advance.');
      }
      yield rows;
      cursor = next;
    }
  }

  Future<List<Map<String, dynamic>>> downloadSamples(
    String sessionId,
    String owner, {
    int pageSize = 500,
  }) async {
    if (pageSize < 1 || pageSize > 1000) {
      throw ArgumentError('Invalid page size.');
    }
    final samples = <Map<String, dynamic>>[];
    var cursor = 0;
    while (true) {
      _check(owner);
      final batch = await client
          .from('obd_recording_samples')
          .select()
          .eq('owner_id', owner)
          .eq('session_id', sessionId)
          .gt('sample_id', cursor)
          .order('sample_id', ascending: true)
          .limit(pageSize)
          .timeout(const Duration(seconds: 15));
      _check(owner);
      samples.addAll(batch);
      if (batch.length < pageSize) return samples;
      final next = (batch.last['sample_id'] as num).toInt();
      if (next <= cursor) {
        throw StateError('Cloud sample cursor did not advance.');
      }
      cursor = next;
    }
  }

  @override
  Future<void> prepare(ObdRecording recording, String owner) async {
    _check(owner);
    final vehicle = recording.vehicle!;
    await client
        .from('vehicles')
        .upsert({
          'id': vehicle.id,
          'owner_id': owner,
          'make': vehicle.make,
          'model': vehicle.model,
          'year': vehicle.year,
          'vin': vehicle.vin,
        }, onConflict: 'id')
        .timeout(const Duration(seconds: 25));
    _check(owner);
    if (compressed) {
      final existing = await client
          .from('obd_recording_sessions')
          .select('storage_format')
          .eq('id', recording.cloudId)
          .maybeSingle()
          .timeout(const Duration(seconds: 25));
      _check(owner);
      _formats[recording.cloudId] =
          existing?['storage_format'] as String? ?? 'gzip-json-v1';
    }
    await client
        .from('obd_recording_sessions')
        .upsert({
          'id': recording.cloudId,
          'owner_id': owner,
          'vehicle_id': vehicle.id,
          'vehicle_name': recording.vehicleName,
          'adapter_name': recording.adapterName,
          'started_at': recording.startedAt.toUtc().toIso8601String(),
          'ended_at': recording.endedAt?.toUtc().toIso8601String(),
          'sample_count': recording.sampleCount,
          if (compressed) 'storage_format': _formats[recording.cloudId],
        }, onConflict: 'id')
        .timeout(const Duration(seconds: 25));
  }

  @override
  Future<void> upload(
    ObdRecording recording,
    String owner,
    List<RecordedObdSample> samples,
  ) async {
    _check(owner);
    if (compressed && _formats[recording.cloudId] == 'gzip-json-v1') {
      if (samples.isEmpty) return;
      final rows = samples
          .map((row) => encodeSample(recording.cloudId, owner, row))
          .toList();
      final bytes = await RecordingChunkCodec.encodeAsync(rows);
      final digest = RecordingChunkCodec.checksum(bytes);
      // The cursor is read from the last server manifest: it also handles a
      // process dying after upload but before its SQLite acknowledgment.
      final previous = await client
          .from('obd_recording_chunks')
          .select('last_sample_id')
          .eq('session_id', recording.cloudId)
          .lt('first_sample_id', samples.first.id)
          .order('first_sample_id', ascending: false)
          .limit(1)
          .timeout(const Duration(seconds: 25));
      _check(owner);
      final objectPath =
          await client
                  .rpc(
                    'reserve_recording_chunk',
                    params: {
                      'recording_id': recording.cloudId,
                      'first_id': samples.first.id,
                      'last_id': samples.last.id,
                      'previous_id': previous.isEmpty
                          ? 0
                          : previous.single['last_sample_id'],
                      'row_count': rows.length,
                      'compressed_bytes': bytes.length,
                      'digest_sha256': digest,
                    },
                  )
                  .timeout(const Duration(seconds: 25))
              as String;
      _check(owner);
      try {
        await client.storage
            .from('obd-recordings')
            .uploadBinary(
              objectPath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'application/gzip',
                upsert: false,
              ),
            )
            .timeout(const Duration(seconds: 30));
      } on StorageException catch (error) {
        if (error.statusCode != '409' && error.error != 'Duplicate') {
          rethrow;
        }
        // Lost acknowledgments are safe only when the immutable bytes match.
        final existing = await client.storage
            .from('obd-recordings')
            .download(objectPath)
            .timeout(const Duration(seconds: 30));
        if (RecordingChunkCodec.checksum(existing) != digest) {
          throw StateError(
            'Conflicting recording object. Local samples are safe.',
          );
        }
      }
      _check(owner);
      return;
    }
    await client
        .from('obd_recording_samples')
        .upsert(
          samples.map((row) {
            final sample = row.sample;
            return {
              'session_id': recording.cloudId,
              'sample_id': row.id,
              'owner_id': owner,
              'pid': sample.parameter.pid,
              'value': sample.value,
              'unit': row.unit,
              'quality': sample.status.name,
              'requested_at': sample.requestedAt.toUtc().toIso8601String(),
              'received_at': sample.receivedAt.toUtc().toIso8601String(),
              'latency_ms': sample.latencyMs,
              'ecu_source': sample.source,
            };
          }).toList(),
          onConflict: 'session_id,sample_id',
          ignoreDuplicates: true,
        )
        .timeout(const Duration(seconds: 25));
  }

  static Map<String, dynamic> encodeSample(
    String session,
    String owner,
    RecordedObdSample row,
  ) => {
    'session_id': session,
    'sample_id': row.id,
    'owner_id': owner,
    'pid': row.sample.parameter.pid,
    'value': row.sample.value,
    'unit': row.unit,
    'quality': row.sample.status.name,
    'requested_at': row.sample.requestedAt.toUtc().toIso8601String(),
    'received_at': row.sample.receivedAt.toUtc().toIso8601String(),
    'latency_ms': row.sample.latencyMs,
    'ecu_source': row.sample.source,
  };

  @override
  Future<void> complete(ObdRecording recording, String owner) async {
    _check(owner);
    await client
        .rpc(
          'complete_obd_recording',
          params: {'recording_id': recording.cloudId},
        )
        .timeout(const Duration(seconds: 25));
  }
}

