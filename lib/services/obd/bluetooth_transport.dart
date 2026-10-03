
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:autopulse_ai/models/obd.dart';

class BluetoothEvent {
  final String type;
  final Uint8List? bytes;
  const BluetoothEvent(this.type, [this.bytes]);
}

abstract interface class BluetoothTransport {
  bool get isSupported;
  Stream<BluetoothEvent> get events;
  Future<bool> requestPermission();
  Future<List<ObdDevice>> pairedDevices();
  Future<void> openSettings();
  Future<void> connect(String address);
  Future<void> write(Uint8List bytes);
  Future<void> disconnect();
}

class ClassicBluetoothTransport implements BluetoothTransport {
  static const _methods = MethodChannel('autopulse/obd/methods');
  static const _events = EventChannel('autopulse/obd/events');
  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Stream<BluetoothEvent> get events =>
      _events.receiveBroadcastStream().map((raw) {
        final event = Map<String, dynamic>.from(raw as Map);
        return BluetoothEvent(
          event['type'] as String,
          event['bytes'] as Uint8List?,
        );
      });
  void _requireAndroid() {
    if (!isSupported) {
      throw UnsupportedError('Bluetooth Classic requires an Android phone.');
    }
  }

  @override
  Future<bool> requestPermission() async {
    _requireAndroid();
    return await _methods.invokeMethod<bool>('permission') ?? false;
  }

  @override
  Future<List<ObdDevice>> pairedDevices() async {
    _requireAndroid();
    final devices = await _methods.invokeListMethod<dynamic>('devices') ?? [];
    return devices.map((raw) {
      final device = Map<String, dynamic>.from(raw as Map);
      return ObdDevice(
        name: device['name'] as String,
        address: device['address'] as String,
      );
    }).toList();
  }

  @override
  Future<void> openSettings() async {
    _requireAndroid();
    await _methods.invokeMethod<void>('settings');
  }

  @override
  Future<void> connect(String address) async {
    _requireAndroid();
    await _methods.invokeMethod<void>('connect', {'address': address});
  }

  @override
  Future<void> write(Uint8List bytes) async {
    await _methods.invokeMethod<void>('write', {'bytes': bytes});
  }

  @override
  Future<void> disconnect() async {
    if (isSupported) await _methods.invokeMethod<void>('disconnect');
  }
}
