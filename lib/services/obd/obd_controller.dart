import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/obd/bluetooth_transport.dart';
import 'package:autopulse_ai/services/obd/elm327_client.dart';
import 'package:autopulse_ai/services/obd/obd_parser.dart';
import 'package:autopulse_ai/services/obd/dtc_monitor.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';
import 'package:autopulse_ai/services/diagnostics/vehicle_diagnostics.dart';

/// App-scoped owner of the connection. Tabs never create independent pollers.
class ObdController extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = ObdController(
    transport: ClassicBluetoothTransport(),
    repository: SqliteObdRecordingRepository(),
  );
  final BluetoothTransport transport;
  final ObdRecordingRepository repository;
  late final Elm327Client _client;
  late final DtcMonitor diagnostics;
  final drivingContext = DrivingContextController();
  final bool observeLifecycle;
  ObdConnectionStatus status = ObdConnectionStatus.disconnected;
  Vehicle vehicle = const Vehicle(make: 'Vehicle', model: '', year: 2020);
  ObdDevice? device;
  List<ObdDevice> devices = [];
  final Map<ObdParameter, ObdSample> _samples = {};
  final Set<ObdParameter> _supported = {};
  final List<ObdSample> _rpmHistory = [];
  String? error;
  String? storageError;
  String? ecuSource;
  String? adapterIdentity;
  bool loadingDevices = false;
  bool recordingBusy = false;
  int savedSamples = 0;
  int? _sessionId;
  int _generation = 0;
  bool _disposed = false;
  Timer? _ageTimer;
  Future<void> _recordQueue = Future.value();
  Future<void>? _stoppingRecording;
  DateTime? _diagnosticScanSince;
  Map<String, dynamic>? _openingScan;
  final _driveCodes = <String, Map>{};
  bool _driveFault = false;
  VehicleDiagnostics? get _pipeline {
    final pipeline = VehicleDiagnostics.instance;
    return identical(pipeline?.store, repository) ? pipeline : null;
  }

  void _observeScan() {
    final since = _diagnosticScanSince;
    if (since == null) return;
    final evidence = diagnosticScan(diagnostics, since);
    _driveFault |= evidence['blocked'] as bool;
    for (final item in evidence['codes'] as List<Map<String, String>>) {
      _driveCodes['${item['code']}:${item['status']}'] = item;
    }
  }

  ObdController({
    required this.transport,
    required this.repository,
    this.observeLifecycle = true,
  }) {
    _client = Elm327Client(transport)..onDisconnected = _onDisconnected;
    diagnostics = DtcMonitor(
      client: _client,
      isReady: () => isReady,
      ecuSource: () => ecuSource,
    );
    diagnostics.addListener(_observeScan);
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
  }
  bool get isReady => status == ObdConnectionStatus.ready;
  bool get isBusy =>
      status == ObdConnectionStatus.connecting ||
      status == ObdConnectionStatus.initializing;
  bool get isRecording => _sessionId != null;
  Map<ObdParameter, ObdSample> get samples => Map.unmodifiable(_samples);
  Set<ObdParameter> get supported => Set.unmodifiable(_supported);
  List<ObdSample> get rpmHistory => List.unmodifiable(_rpmHistory);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void setVehicle(Vehicle value) {
    if (vehicle.id != value.id ||
        vehicle.ownerId != value.ownerId ||
        vehicle.make != value.make ||
        vehicle.model != value.model ||
        vehicle.year != value.year ||
        vehicle.vin != value.vin) {
      if (isRecording) _driveFault = true;
      diagnostics.reset();
      drivingContext.reset(connected: isReady);
    }
    vehicle = value;
    _changed();
  }

  String _message(Object exception) => switch (exception) {
    PlatformException() => exception.message ?? 'Bluetooth operation failed.',
    ElmException() => exception.message,
    _ => 'Operation failed. Check adapter power, pairing, and ignition.',
  };

  Future<void> loadDevices() async {
    if (loadingDevices || isBusy || isReady) return;
    loadingDevices = true;
    error = null;
    _changed();
    try {
      if (!transport.isSupported) {
        throw const ElmException(
          'Bluetooth Classic requires an Android phone.',
        );
      }
      if (!await transport.requestPermission()) {
        throw const ElmException('Bluetooth permission was denied.');
      }
      devices = await transport.pairedDevices();
    } catch (exception) {
      devices = [];
      error = _message(exception);
    } finally {
      loadingDevices = false;
      _changed();
    }
  }

  Future<void> openSettings() async {
    try {
      await transport.openSettings();
    } catch (exception) {
      error = _message(exception);
      _changed();
    }
  }

  Future<void> connect(ObdDevice selected) async {
    if (isBusy || _disposed) return;
    final generation = ++_generation;
    _ageTimer?.cancel();
    device = selected;
    status = ObdConnectionStatus.connecting;
    diagnostics.reset();
    drivingContext.reset();
    error = null;
    storageError = null;
    _samples.clear();
    _supported.clear();
    _rpmHistory.clear();
    ecuSource = null;
    adapterIdentity = null;
    _changed();
    try {
      // Claim the attempt before asynchronous cleanup so a second tap cannot
      // create another socket, and Disconnect can cancel this attempt too.
      await _client.disconnect();
      await stopRecording();
      if (generation != _generation || _disposed) return;
      if (!await transport.requestPermission()) {
        throw const ElmException('Bluetooth permission was denied.');
      }
      if (generation != _generation) return;
      await _client.connect(selected.address);
      if (generation != _generation) return;
      status = ObdConnectionStatus.initializing;
      _changed();
      final identity = await _client.initialize();
      if (generation != _generation) return;
      final bitmap = await _client.command(
        '0100',
        timeout: const Duration(seconds: 15),
      );
      if (generation != _generation) return;
      final reply = ObdParser.select(ObdParser.responses(bitmap, 0, 4));
      adapterIdentity = identity;
      ecuSource = reply.source;
      final pids = ObdParser.supported(reply.bytes);
      _supported.addAll(ObdParameter.values.where((p) => pids.contains(p.pid)));
      if (_supported.isEmpty) {
        throw const ElmException(
          'ECU exposes none of the supported live parameters.',
        );
      }
      if (generation != _generation) return;
      status = ObdConnectionStatus.ready;
      drivingContext.reset(connected: true);
      _ageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        drivingContext.expire(DateTime.now());
        _changed();
      });
      _changed();
      unawaited(_poll(generation));
    } catch (exception) {
      if (generation != _generation || _disposed) return;
      await _client.disconnect();
      _ageTimer?.cancel();
      status = ObdConnectionStatus.error;
      error = _message(exception);
      _changed();
    }
  }

  Future<void> _poll(int generation) async {
    final lastRead = <ObdParameter, DateTime>{};
    try {
      while (!_disposed && generation == _generation && isReady) {
        if (diagnostics.due) await diagnostics.scan();
        for (final parameter in ObdParameter.values.where(
          _supported.contains,
        )) {
          if (generation != _generation || !isReady) return;
          final interval =
              parameter == ObdParameter.rpm || parameter == ObdParameter.speed
              ? Duration.zero
              : const Duration(seconds: 3);
          final now = DateTime.now();
          if (lastRead[parameter] != null &&
              now.difference(lastRead[parameter]!) < interval) {
            continue;
          }
          lastRead[parameter] = now;
          final watch = Stopwatch()..start();
          final raw = await _client.command(parameter.command);
          watch.stop();
          if (generation != _generation || !isReady) return;
          final replies = ObdParser.responses(
            raw,
            parameter.pid,
            parameter.byteCount,
          );
          double? value;
          var quality = ObdSampleStatus.valid;
          if (raw.toUpperCase().contains('NO DATA')) {
            quality = ObdSampleStatus.noData;
          } else {
            try {
              value = ObdParser.decode(
                parameter,
                ObdParser.select(replies, source: ecuSource).bytes,
              );
            } catch (_) {
              quality = ObdSampleStatus.invalid;
            }
          }
          final sample = ObdSample(
            parameter: parameter,
            value: value,
            status: quality,
            requestedAt: now,
            receivedAt: DateTime.now(),
            latencyMs: watch.elapsedMilliseconds,
            source: ecuSource,
          );
          _samples[parameter] = sample;
          // Explicit accepted-attempt hook: storage/status UI notifications are
          // not new sensor evidence. Reuse this connection and polling schedule.
          drivingContext.accept(sample);
          if (parameter == ObdParameter.rpm) {
            _rpmHistory.add(sample);
            if (_rpmHistory.length > 120) _rpmHistory.removeAt(0);
          }
          _record(sample);
          _changed();
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    } catch (exception) {
      if (generation != _generation || _disposed) return;
      await disconnect();
      status = ObdConnectionStatus.error;
      error = _message(exception);
      _changed();
    }
  }

  Future<void> startRecording() async {
    if (!isReady || device == null || isRecording || recordingBusy) return;
    final generation = _generation;
    recordingBusy = true;
    storageError = null;
    _changed();
    try {
      if (_pipeline != null) {
        _driveCodes.clear();
        _driveFault = false;
        _diagnosticScanSince = DateTime.now();
        final since = await diagnostics.scanForRecording();
        _openingScan = diagnosticScan(diagnostics, since);
        if (!isReady || _disposed || generation != _generation) return;
      }
      final id = await repository.start(vehicle, device!);
      if (!isReady || _disposed || generation != _generation) {
        await repository.finish(id);
        return;
      }
      _sessionId = id;
      savedSamples = 0;
    } catch (_) {
      storageError = 'Could not start local recording.';
    } finally {
      if (!isRecording) _diagnosticScanSince = null;
      recordingBusy = false;
      _changed();
    }
  }

  void _record(ObdSample sample) {
    final session = _sessionId;
    if (session == null) return;
    // Serialize storage so stop waits for every accepted sample before finalizing.
    _recordQueue = _recordQueue.then((_) async {
      try {
        await repository.append(session, sample);
        savedSamples++;
      } catch (_) {
        storageError =
            'A reading could not be saved. Stop recording and check storage.';
      }
      _changed();
    });
  }

  Future<void> stopRecording() {
    final stopping = _stoppingRecording;
    if (stopping != null) return stopping;
    final session = _sessionId;
    if (session == null) return Future.value();
    _sessionId = null;
    recordingBusy = true;
    _changed();
    return _stoppingRecording = _finishRecording(session).whenComplete(() {
      _stoppingRecording = null;
    });
  }

  Future<void> _finishRecording(int session) async {
    try {
      await _recordQueue;
      final pipeline = _pipeline;
      if (pipeline != null) {
        final since = await diagnostics.scanForRecording();
        final closing = diagnosticScan(diagnostics, since);
        _observeScan();
        try {
          await pipeline.attachScan(session, {
            'complete':
                isReady &&
                _openingScan?['complete'] == true &&
                closing['complete'] == true,
            'blocked':
                _driveFault ||
                _openingScan?['blocked'] == true ||
                closing['blocked'] == true,
            'codes': _driveCodes.values.toList(),
          });
        } catch (_) {
          // A failed write leaves the drive ineligible for reference fitting.
          storageError = 'ECU scan evidence could not be stored.';
        }
      }
      await repository.finish(session);
      if (pipeline != null) {
        unawaited(pipeline.evaluate(session).then((_) => pipeline.refresh()));
      }
    } catch (_) {
      storageError = 'Recording could not be finalized; saved samples remain on this phone.';
    } finally {
      _diagnosticScanSince = null;
      _openingScan = null;
      recordingBusy = false;
      _changed();
    }
  }

  void _onDisconnected() {
    _generation++;
    _ageTimer?.cancel();
    status = ObdConnectionStatus.disconnected;
    diagnostics.disconnected();
    drivingContext.reset();
    error = 'Adapter disconnected. Reconnect to resume.';
    unawaited(stopRecording());
    _changed();
  }

  Future<void> disconnect() async {
    _generation++;
    _ageTimer?.cancel();
    status = ObdConnectionStatus.disconnected;
    diagnostics.disconnected();
    drivingContext.reset();
    await _client.disconnect();
    await stopRecording();
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && (isReady || isBusy)) {
      unawaited(disconnect());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    _ageTimer?.cancel();
    unawaited(disconnect());
    diagnostics.dispose();
    drivingContext.dispose();
    super.dispose();
  }
}
