import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/obd/bluetooth_transport.dart';
import 'package:autopulse_ai/services/obd/elm327_client.dart';
import 'package:autopulse_ai/services/obd/obd_parser.dart';

/// App-scoped owner of the connection. Tabs never create independent pollers.
class ObdController extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = ObdController(
    transport: ClassicBluetoothTransport(),
    repository: SqliteObdRecordingRepository(),
  );
  final BluetoothTransport transport;
  final ObdRecordingRepository repository;
  late final Elm327Client _client;
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

  ObdController({
    required this.transport,
    required this.repository,
    this.observeLifecycle = true,
  }) {
    _client = Elm327Client(transport)..onDisconnected = _onDisconnected;
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
    await disconnect();
    final generation = ++_generation;
    device = selected;
    status = ObdConnectionStatus.connecting;
    error = null;
    storageError = null;
    _samples.clear();
    _supported.clear();
    _rpmHistory.clear();
    ecuSource = null;
    adapterIdentity = null;
    _changed();
    try {
      if (!await transport.requestPermission()) {
        throw const ElmException('Bluetooth permission was denied.');
      }
      if (generation != _generation) return;
      await _client.connect(selected.address);
      if (generation != _generation) return;
      status = ObdConnectionStatus.initializing;
      _changed();
      adapterIdentity = await _client.initialize();
      final bitmap = await _client.command(
        '0100',
        timeout: const Duration(seconds: 15),
      );
      final reply = ObdParser.select(ObdParser.responses(bitmap, 0, 4));
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
      _ageTimer = Timer.periodic(const Duration(seconds: 1), (_) => _changed());
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
          if (parameter == ObdParameter.rpm && value != null) {
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
    recordingBusy = true;
    storageError = null;
    _changed();
    try {
      final id = await repository.start(vehicle, device!);
      if (!isReady || _disposed) {
        await repository.finish(id);
        return;
      }
      _sessionId = id;
      savedSamples = 0;
    } catch (_) {
      storageError = 'Could not start local recording.';
    } finally {
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

  Future<void> stopRecording() async {
    final session = _sessionId;
    if (session == null || recordingBusy) return;
    _sessionId = null;
    recordingBusy = true;
    _changed();
    try {
      await _recordQueue;
      await repository.finish(session);
    } catch (_) {
      storageError = 'Recording could not be finalized; saved samples remain on this phone.';
    } finally {
      recordingBusy = false;
      _changed();
    }
  }

  void _onDisconnected() {
    _generation++;
    _ageTimer?.cancel();
    status = ObdConnectionStatus.disconnected;
    error = 'Adapter disconnected. Reconnect to resume.';
    unawaited(stopRecording());
    _changed();
  }

  Future<void> disconnect() async {
    _generation++;
    _ageTimer?.cancel();
    status = ObdConnectionStatus.disconnected;
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
    super.dispose();
  }
}
