import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';

/// Uploads immutable, finished sessions. Network work never enters the PID queue.
class RecordingSyncService extends ChangeNotifier with WidgetsBindingObserver {
  static RecordingSyncService? instance;
  final RecordingStore store;
  final CloudRecordingRepository cloud;
  final int batchSize;
  final bool automaticRetry;
  bool busy = false;
  int? activeRecordingId;
  String? message;
  Timer? _retry;
  int _failures = 0;
  bool _disposed = false;
  bool _foreground = true;
  StreamSubscription<AuthState>? _auth;

  RecordingSyncService({
    required this.store,
    required this.cloud,
    this.batchSize = 250,
    this.automaticRetry = true,
  }) {
    if (batchSize < 1 || batchSize > 1000) {
      throw ArgumentError('Invalid batch size.');
    }
  }

  void start(SupabaseClient client) {
    WidgetsBinding.instance.addObserver(this);
    _auth = client.auth.onAuthStateChange.listen((_) {
      _retry?.cancel();
      if (cloud.ownerId != null) unawaited(retryPending());
    });
    unawaited(retryPending());
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _check(String owner) {
    if (_disposed || cloud.ownerId != owner) {
      throw StateError('Account changed. Upload paused.');
    }
  }

  Future<void> upload(int id) async {
    if (busy || _disposed) return;
    final owner = cloud.ownerId;
    if (owner == null) throw StateError('Sign in before uploading recordings.');
    busy = true;
    activeRecordingId = id;
    message = 'Preparing upload…';
    _retry?.cancel();
    _changed();
    var claimed = false;
    try {
      final recording = await store.claimCompleted(id, owner);
      claimed = true;
      _check(owner);
      if (recording.syncState == RecordingSyncState.synced) return;
      await store.setSyncState(id, owner, RecordingSyncState.uploading);
      await cloud.prepare(recording, owner);
      _check(owner);
      var cursor = recording.uploadedSampleId;
      while (true) {
        final samples = await store.samples(
          id,
          afterId: cursor,
          limit: batchSize,
        );
        _check(owner);
        if (samples.isEmpty) break;
        await cloud.upload(recording, owner, samples);
        _check(owner);
        // Persist only after acknowledgment. Lost acknowledgments replay safely.
        cursor = samples.last.id;
        await store.checkpoint(id, owner, cursor);
        message = 'Uploading ${recording.vehicleName}…';
        _changed();
      }
      _check(owner);
      await cloud.complete(recording, owner);
      _check(owner);
      await store.setSyncState(id, owner, RecordingSyncState.synced);
      _failures = 0;
      message = 'Recording backed up.';
    } catch (error) {
      message = _errorMessage(error);
      if (claimed) {
        await store.setSyncState(
          id,
          owner,
          RecordingSyncState.failed,
          error: message,
        );
      }
      if (automaticRetry && cloud.ownerId == owner && _retryable(error)) {
        _schedule();
      }
      rethrow;
    } finally {
      busy = false;
      activeRecordingId = null;
      _changed();
    }
  }

  bool _retryable(Object error) =>
      error is! StateError &&
      error is! ArgumentError &&
      error is! AuthException &&
      !(error is PostgrestException &&
          [
            '42501',
            'PGRST205',
            '42883',
            '23503',
            '23514',
            '23505',
          ].contains(error.code));

  String _errorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is AuthException) return 'Sign in again to resume cloud backup.';
    if (error is PostgrestException &&
        ['42501', 'PGRST205', '42883'].contains(error.code)) {
      return 'Cloud storage is not ready. Check the recording migration and account permissions.';
    }
    return 'Upload failed. Local samples are safe; retry when connected.';
  }

  void _schedule() {
    if (_disposed || !_foreground) return;
    final seconds = min(300, 5 * (1 << min(_failures++, 6)));
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), () => unawaited(retryPending()));
  }

  /// Only sessions explicitly queued by a user are retried automatically.
  Future<void> retryPending() async {
    if (busy || _disposed || !_foreground) return;
    final owner = cloud.ownerId;
    if (owner == null) return;
    try {
      var before = 0;
      while (!_disposed && cloud.ownerId == owner) {
        final recordings = await store.listRecordings(owner, beforeId: before);
        if (recordings.isEmpty) return;
        for (final recording in recordings) {
          if (recording.ownerId != owner ||
              recording.endedAt == null ||
              ![
                RecordingSyncState.pending,
                RecordingSyncState.failed,
                RecordingSyncState.uploading,
              ].contains(recording.syncState)) {
            continue;
          }
          if (busy) return;
          await upload(recording.id);
          _check(owner);
        }
        before = recordings.last.id;
      }
    } catch (_) {
      // upload() persists failure and schedules transient retries; avoid unhandled futures.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(retryPending());
    } else {
      _retry?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    unawaited(_auth?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
