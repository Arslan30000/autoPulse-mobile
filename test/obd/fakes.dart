import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/obd/bluetooth_transport.dart';

class FakeBluetoothTransport implements BluetoothTransport {
  final stream = StreamController<BluetoothEvent>.broadcast(sync: true);
  final List<String> writes = [];
  bool allowed = true;
  bool automatic = false;
  String Function(String command)? reply;
  Future<void> Function(String command)? onWrite;
  @override
  bool isSupported = true;
  @override
  Stream<BluetoothEvent> get events => stream.stream;
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<List<ObdDevice>> pairedDevices() async => [
    const ObdDevice(name: 'ELM327 test', address: '00:11:22:33:44:55'),
  ];
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> connect(String address) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> write(Uint8List bytes) async {
    final command = ascii.decode(bytes).trim();
    writes.add(command);
    await onWrite?.call(command);
    if (automatic) receive('${reply?.call(command) ?? defaultReply(command)}>');
  }

  void receive(String text) => stream.add(
    BluetoothEvent('data', Uint8List.fromList(ascii.encode(text))),
  );
  void loseConnection() => stream.add(const BluetoothEvent('disconnected'));
  String defaultReply(String command) {
    if (command == 'ATZ') return 'ELM327 v1.5\r';
    if (command.startsWith('AT')) return 'OK\r';
    if (command == '0100') {
      var mask = 0;
      for (final p in ObdParameter.values) {
        mask |= 1 << (32 - p.pid);
      }
      final hex = mask.toRadixString(16).padLeft(8, '0').toUpperCase();
      return '7E8 06 41 00 ${[for (var i = 0; i < 8; i += 2) hex.substring(i, i + 2)].join(' ')}\r';
    }
    final p = ObdParameter.values.firstWhere((p) => p.command == command);
    return '7E8 ${p.byteCount == 2 ? '04' : '03'} 41 ${p.pidHex} ${p.byteCount == 2 ? '1A F8' : '80'}\r';
  }

  Future<void> close() => stream.close();
}

class MemoryRecordingRepository implements ObdRecordingRepository {
  final List<ObdSample> samples = [];
  int starts = 0;
  int finishes = 0;
  bool failWrites = false;
  @override
  Future<int> start(Vehicle vehicle, ObdDevice device) async => ++starts;
  @override
  Future<void> append(int sessionId, ObdSample sample) async {
    if (failWrites) throw StateError('Storage full');
    samples.add(sample);
  }

  @override
  Future<void> finish(int sessionId) async {
    finishes++;
  }

  @override
  Future<List<ObdRecording>> recordings() async => [];
}

Future<void> waitUntil(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 3)) {
      throw StateError('Condition did not become true');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
