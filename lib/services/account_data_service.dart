import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/local_vehicle_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';
import 'package:autopulse_ai/services/recording_restore_service.dart';

/// Account data is cached by owner; signing out never deletes phone recordings.
class AccountDataService extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = AccountDataService();
  final vehicles = LocalVehicleRepository();
  bool busy = false;
  String? message;
  String? syncError;
  int restoredRuns = 0;
  int restoredSamples = 0;
  int restoreTotalSamples = 0;
  double? get restoreProgress => restoreTotalSamples == 0
      ? null
      : (restoredSamples / restoreTotalSamples).clamp(0.0, 1.0);
  int? cloudReservedBytes;
  int cloudBudgetBytes = 850000000;
  int? accountCloudBytes;
  bool get cloudNearlyFull =>
      cloudReservedBytes != null &&
      cloudReservedBytes! >= cloudBudgetBytes * .8;
  String? resolvedOwner;
  Timer? _timer;
  StreamSubscription<void>? _auth;
  String? _activeOwner;
  String? _pendingOwner;
  bool _pendingCarsOnly = false;
  Future<void>? _pending;
  Completer<void>? _carsReady;
  bool _foreground = true;
  bool get canStoreRuns =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _activeOwner = AccountService.instance.userId;
    _auth = AccountService.instance.changes.listen((_) async {
      final owner = AccountService.instance.userId;
      if (_activeOwner == owner) return;
      _activeOwner = owner;
      resolvedOwner = null;
      accountCloudBytes = null;
      cloudReservedBytes = null;
      try {
        await ObdController.instance.disconnect();
        ObdController.instance.diagnostics.reset();
        await restoreSelection(cloud: owner != null);
      } catch (_) {
        message = 'Account data could not be loaded. Retry from Settings.';
      }
      notifyListeners();
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground && AccountService.instance.userId != null) {
        unawaited(synchronize());
      }
    });
  }

  void _check(String owner) {
    if (AccountService.instance.userId != owner) {
      throw StateError('Account changed.');
    }
  }

  Future<Vehicle?> restoreSelection({bool cloud = true}) async {
    final owner = AccountService.instance.userId;
    var vehicle = await vehicles.load(owner);
    if (cloud && owner != null && vehicle == null && resolvedOwner != owner) {
      await synchronize(carsOnly: true);
      vehicle = await vehicles.load(owner);
    }
    if (AccountService.instance.userId != owner) {
      throw StateError('Account changed.');
    }
    ObdController.instance.setVehicle(
      vehicle ?? const Vehicle(make: 'Vehicle', model: '', year: 2020),
    );
    // Opening the app must not wait for potentially large recording transfers.
    if (cloud &&
        owner != null &&
        canStoreRuns &&
        (vehicle != null || resolvedOwner == owner)) {
      unawaited(synchronize());
    }
    return vehicle;
  }

  Future<Vehicle> addVehicle(Vehicle vehicle) async {
    final obd = ObdController.instance;
    if (obd.isRecording || obd.recordingBusy) {
      throw StateError('Stop recording before adding a car.');
    }
    if (obd.isReady || obd.isBusy) await obd.disconnect();
    final owner = AccountService.instance.userId;
    final saved = await vehicles.save(vehicle, owner);
    if (AccountService.instance.userId != owner) {
      throw StateError('Account changed.');
    }
    ObdController.instance.setVehicle(saved);
    // The local commit comes first; a failed connection leaves a durable retry.
    if (owner != null) unawaited(synchronize());
    notifyListeners();
    return saved;
  }

  Future<void> chooseVehicle(Vehicle vehicle) async {
    final obd = ObdController.instance;
    if (obd.isRecording || obd.recordingBusy) {
      throw StateError('Stop recording before switching cars.');
    }
    await obd.disconnect();
    await vehicles.select(vehicle, AccountService.instance.userId);
    ObdController.instance.setVehicle(vehicle);
    notifyListeners();
  }

  Future<void> synchronize({bool carsOnly = false}) async {
    final owner = AccountService.instance.userId;
    final pending = _pending;
    if (pending != null) {
      final pendingOwner = _pendingOwner;
      final pendingCarsOnly = _pendingCarsOnly;
      if (carsOnly && pendingOwner == owner) {
        // A background run restore may still be active after cars are ready.
        await (_carsReady?.future ?? pending);
        return;
      }
      await pending;
      if (AccountService.instance.userId != owner ||
          (pendingOwner == owner && (!pendingCarsOnly || carsOnly))) {
        return;
      }
      // Other callers may have started the next sync while we were waiting.
      // Rejoin it without replacing its car-ready signal.
      return synchronize(carsOnly: carsOnly);
    }
    _pendingOwner = owner;
    _pendingCarsOnly = carsOnly;
    final carsReady = _carsReady = Completer<void>();
    await (_pending ??= _synchronize(
      carsOnly: carsOnly,
      carsReady: carsReady,
    ).whenComplete(() => _pending = null));
  }

  Future<void> _synchronize({
    required bool carsOnly,
    required Completer<void> carsReady,
  }) async {
    final account = AccountService.instance;
    final owner = account.userId;
    final client = account.client;
    if (owner == null || client == null) {
      carsReady.complete();
      return;
    }
    busy = true;
    syncError = null;
    restoredRuns = 0;
    restoredSamples = 0;
    restoreTotalSamples = 0;
    message = 'Syncing account...';
    notifyListeners();
    try {
      for (final vehicle in await vehicles.pending(owner)) {
        _check(owner);
        await client
            .from('vehicles')
            .upsert({
              ...LocalVehicleRepository.encode(vehicle),
              'owner_id': owner,
            }, onConflict: 'id')
            .timeout(const Duration(seconds: 15));
        _check(owner);
        await vehicles.acknowledge(owner, vehicle.id!);
      }
      final cars = <Vehicle>[];
      for (var offset = 0; ; offset += 100) {
        final page = await client
            .from('vehicles')
            .select()
            .eq('owner_id', owner)
            .order('id')
            .range(offset, offset + 99)
            .timeout(const Duration(seconds: 15));
        _check(owner);
        cars.addAll(page.map((r) => LocalVehicleRepository.decode(r, owner)));
        if (page.length < 100) break;
      }
      await vehicles.mergeCloud(cars, owner);
      _check(owner);
      resolvedOwner = owner;
      carsReady.complete();
      if (carsOnly) {
        message = 'Cars restored. Runs are syncing in the background.';
        return;
      }
      if (account.usesFirebase) {
        try {
          final usage = await client
              .rpc('recording_cloud_usage')
              .timeout(const Duration(seconds: 15));
          _check(owner);
          if (usage is Map) {
            cloudReservedBytes = (usage['reserved_bytes'] as num).toInt();
            cloudBudgetBytes = (usage['budget_bytes'] as num).toInt();
            accountCloudBytes = (usage['account_bytes'] as num).toInt();
          }
        } catch (_) {
          // Usage information must never stop car restoration or local capture.
          _check(owner);
        }
      }
      if (canStoreRuns) {
        final store =
            ObdController.instance.repository as SqliteObdRecordingRepository;
        // Automatically back up completed account runs. Offline runs require
        // explicit ownership assignment using their existing upload button.
        var before = 0;
        while (true) {
          final page = await store.listRecordings(owner, beforeId: before);
          if (page.isEmpty) break;
          for (final run in page) {
            _check(owner);
            if (run.ownerId == owner &&
                run.endedAt != null &&
                run.syncState == RecordingSyncState.local) {
              await store.claimCompleted(run.id, owner);
            }
          }
          before = page.last.id;
        }
        final ids = await (await store.database).query(
          'sessions',
          columns: ['cloud_id'],
          where: 'owner_id = ?',
          whereArgs: [owner],
        );
        final existing = ids.map((r) => r['cloud_id']).toSet();
        final restorer = RecordingRestoreService(
          store: store,
          cloud: SupabaseRecordingRepository(
            client,
            accountOwner: () => account.userId,
            compressed: true,
          ),
        );
        for (var offset = 0; ; offset += 50) {
          final page = await client
              .from('obd_recording_sessions')
              .select()
              .eq('owner_id', owner)
              .not('uploaded_at', 'is', null)
              .order('started_at', ascending: false)
              .order('id')
              .range(offset, offset + 49)
              .timeout(const Duration(seconds: 15));
          _check(owner);
          for (final run in page) {
            if (existing.contains(run['id'])) continue;
            message = 'Restoring saved runs ($restoredRuns restored)...';
            notifyListeners();
            try {
              final car = cars.firstWhere((v) => v.id == run['vehicle_id']);
              await restorer.restore(
                run,
                car,
                owner,
                onProgress: (done, total) {
                  restoredSamples = done;
                  restoreTotalSamples = total;
                  message =
                      'Restoring ${car.displayName}: $done of $total readings ($restoredRuns drives ready)...';
                  notifyListeners();
                },
              );
              _check(owner);
              existing.add(run['id']);
              restoredRuns++;
              message = '$restoredRuns drives restored and ready to open.';
              notifyListeners();
            } catch (error, stack) {
              _check(owner);
              debugPrint(
                'Recording restore failed (${run['id']}): $error\n$stack',
              );
              syncError =
                  'A saved run could not be restored. ${_syncErrorMessage(error)}';
            }
          }
          if (page.length < 50) break;
        }
        // Pending uploads can be large too. Do not make drive restoration wait
        // for them; their own durable queue and retry handling remain active.
        unawaited(RecordingSyncService.instance?.retryPending());
      }
      var waiting = false;
      if (canStoreRuns) {
        final db =
            await (ObdController.instance.repository
                    as SqliteObdRecordingRepository)
                .database;
        waiting = (await db.query(
          'sessions',
          columns: ['id'],
          where: "owner_id = ? AND ended_at IS NOT NULL AND sync_state <> 'synced'",
          whereArgs: [owner],
          limit: 1,
        )).isNotEmpty;
      }
      message =
          syncError ??
          (waiting
              ? 'Cars restored. Some runs are waiting for backup; keep the app open and retry when online.'
              : 'Account synced. $restoredRuns runs restored. Cars and uploaded runs are available offline.');
    } catch (error, stack) {
      debugPrint('Account sync failed: $error\n$stack');
      syncError = _syncErrorMessage(error);
      message = 'Cloud sync unavailable. $syncError Saved phone data is safe.';
    } finally {
      if (!carsReady.isCompleted) carsReady.complete();
      restoredSamples = 0;
      restoreTotalSamples = 0;
      busy = false;
      notifyListeners();
    }
  }

  String _syncErrorMessage(Object error) {
    if (error is PostgrestException) {
      return 'Database error ${error.code ?? ''}: ${error.message}';
    }
    if (error is AuthException) return 'Sign in again to restore your runs.';
    if (error is TimeoutException) {
      return 'The connection timed out. Tap Refresh to retry.';
    }
    if (error is StateError) return error.message.toString();
    return 'Check your internet connection and tap Refresh to retry.';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(synchronize());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_auth?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
