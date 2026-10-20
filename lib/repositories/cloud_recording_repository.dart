import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';

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
  const SupabaseRecordingRepository(this.client);
  @override
  String? get ownerId => client.auth.currentUser?.id;

  void _check(String owner) {
    if (ownerId != owner) {
      throw StateError('Sign in to the recording owner account.');
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
    await client
        .from('obd_recording_sessions')
        .upsert({
          'id': recording.cloudId,
          'owner_id': owner,
          'vehicle_id': vehicle.id,
          'vehicle_name': recording.vehicleName,
          'adapter_name': recording.adapterName,
          'started_at': recording.startedAt.toUtc().toIso8601String(),
          'ended_at': recording.endedAt!.toUtc().toIso8601String(),
          'sample_count': recording.sampleCount,
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
