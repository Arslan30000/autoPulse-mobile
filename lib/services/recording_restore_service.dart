import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';

/// Resume only after the last durably committed page. Full validation and the
/// atomic publication of completed recordings remain owned by the SQLite store.
class RecordingRestoreService {
  final SqliteObdRecordingRepository store;
  final SupabaseRecordingRepository cloud;
  const RecordingRestoreService({required this.store, required this.cloud});

  Future<void> restore(
    Map<String, dynamic> run,
    Vehicle car,
    String owner, {
    void Function(int restored, int total)? onProgress,
  }) async {
    final cursor = await store.restoreCursor(run, owner);
    Future<void> download(int afterId) => store.importCloudPages(
      run,
      car,
      cloud.samplePages(run, owner, afterId: afterId),
      owner,
      onProgress: onProgress,
    );
    try {
      await download(cursor);
    } on StateError catch (error) {
      final message = error.message.toString();
      if (cursor == 0 ||
          !(message.startsWith('Cloud restore received ') ||
              message.startsWith('Recording chunk chain '))) {
        rethrow;
      }
      // An older/inconsistent staged prefix may not represent a full chunk or
      // may have skipped rows. Repair it once, only after integrity validation
      // proves resuming cannot succeed. Network failures never clear progress.
      await store.restartRestore(run, owner);
      await download(0);
    }
  }
}
