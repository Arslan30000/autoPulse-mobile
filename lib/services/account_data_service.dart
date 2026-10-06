import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/local_vehicle_repository.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';

/// Account data is cached by owner; signing out never deletes phone recordings.
class AccountDataService extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = AccountDataService();
  final vehicles = LocalVehicleRepository();
  bool busy = false;
  String? message;
  String? resolvedOwner;
  Timer? _timer;
  StreamSubscription<AuthState>? _auth;
  String? _activeOwner;
  String? _pendingOwner;
  bool _pendingCarsOnly = false;
  Future<void>? _pending;
  bool _foreground = true;
  bool get canStoreRuns =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _activeOwner = AccountService.instance.userId;
    _auth = AccountService.instance.client?.auth.onAuthStateChange.listen((
      _,
    ) async {
      final owner = AccountService.instance.userId;
      if (_activeOwner == owner) return;
      _activeOwner = owner;
      resolvedOwner = null;
      try {
        await ObdController.instance.disconnect();
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
    if (cloud && owner != null) await synchronize(carsOnly: true);
    final vehicle = await vehicles.load(owner);
    if (AccountService.instance.userId != owner) {
      throw StateError('Account changed.');
    }
    ObdController.instance.setVehicle(
      vehicle ?? const Vehicle(make: 'Vehicle', model: '', year: 2020),
    );
    if (cloud && owner != null && canStoreRuns) unawaited(synchronize());
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
      await pending;
      if (AccountService.instance.userId != owner ||
          (pendingOwner == owner && (!pendingCarsOnly || carsOnly))) {
        return;
      }
    }
    _pendingOwner = owner;
    _pendingCarsOnly = carsOnly;
    await (_pending ??= _synchronize(carsOnly: carsOnly)
        .whenComplete(() => _pending = null));
  }

  Future<void> _synchronize({required bool carsOnly}) async {
    final account = AccountService.instance;
    final owner = account.userId;
    final client = account.client;
    if (owner == null || client == null) return;
    busy = true;
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
      if (carsOnly) {
        message = 'Cars restored. Runs are syncing in the background.';
        return;
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
        await RecordingSyncService.instance?.retryPending();
        final ids = await (await store.database).query(
          'sessions',
          columns: ['cloud_id'],
          where: 'owner_id = ?',
          whereArgs: [owner],
        );
        final existing = ids.map((r) => r['cloud_id']).toSet();
        for (var offset = 0; ; offset += 50) {
          final page = await client
              .from('obd_recording_sessions')
              .select()
              .eq('owner_id', owner)
              .not('uploaded_at', 'is', null)
              .order('id')
              .range(offset, offset + 49)
              .timeout(const Duration(seconds: 15));
          _check(owner);
          for (final run in page) {
            if (existing.contains(run['id'])) continue;
            final car = cars.firstWhere((v) => v.id == run['vehicle_id']);
            final samples = <Map<String, dynamic>>[];
            var cursor = 0;
            while (true) {
              final batch = await client
                  .from('obd_recording_samples')
                  .select()
                  .eq('owner_id', owner)
                  .eq('session_id', run['id'])
                  .gt('sample_id', cursor)
                  .order('sample_id')
                  .limit(500)
                  .timeout(const Duration(seconds: 15));
              _check(owner);
              samples.addAll(batch);
              if (batch.length < 500) break;
              cursor = (batch.last['sample_id'] as num).toInt();
            }
            await store.importCloud(run, car, samples, owner);
          }
          if (page.length < 50) break;
        }
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
      message = waiting
          ? 'Cars restored. Some runs are waiting for backup; keep the app open and retry when online.'
          : 'Account synced. Cars and uploaded runs are available offline.';
    } catch (_) {
      message = 'Cloud sync unavailable. Saved phone data is safe; we will retry when connected.';
    } finally {
      busy = false;
      notifyListeners();
    }
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
