import 'dart:io';

import 'package:bluetooth_serial_android/bluetooth_serial_android.dart';

class ObdDevice {
  const ObdDevice({required this.name, required this.address});

  final String name;
  final String address;
}

/// Android Bluetooth Classic (SPP/RFCOMM) transport for paired ELM327 adapters.
///
/// This intentionally starts with a small command/response surface. It does not
/// yet stream or persist telemetry.
class Elm327Service {
  static const _sppUuid = '00001101-0000-1000-8000-00805F9B34FB';
  static const _responseTerminator = '>';

  bool _connected = false;

  bool get isConnected => _connected;

  Future<List<ObdDevice>> getPairedDevices() async {
    _requireAndroid();
    final granted = await FlutterBluetoothSerial.ensurePermissions();
    if (!granted) {
      throw StateError('Bluetooth permission was not granted.');
    }

    final devices = await FlutterBluetoothSerial.getPairedDevices();
    return devices
        .where((device) => (device['address'] ?? '').isNotEmpty)
        .map(
          (device) => ObdDevice(
            name: device['name']?.trim().isNotEmpty == true
                ? device['name']!.trim()
                : 'Unknown Bluetooth device',
            address: device['address']!,
          ),
        )
        .toList(growable: false);
  }

  Future<void> connect(ObdDevice device) async {
    _requireAndroid();
    final granted = await FlutterBluetoothSerial.ensurePermissions();
    if (!granted) {
      throw StateError('Bluetooth permission was not granted.');
    }

    final connected = await FlutterBluetoothSerial.connect(
      device.address,
      uuid: _sppUuid,
      // The plugin uses this for the serial read timeout, not the RFCOMM
      // connection timeout. Keep reads responsive while waiting for a prompt.
      timeoutMs: 300,
    );
    if (!connected) {
      throw StateError('Could not connect to ${device.name}.');
    }
    _connected = true;
  }

  /// Resets and configures the ELM327, then returns its ATI identification.
  Future<String> initializeAdapter() async {
    _requireConnected();
    await _sendCommand('ATZ', timeout: const Duration(seconds: 8));
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await _sendCommand('ATE0'); // Disable command echo.
    await _sendCommand('ATL0'); // Disable line feeds.
    await _sendCommand('ATS0'); // Remove response spaces.
    await _sendCommand('ATSP0'); // Automatic vehicle protocol detection.
    final identification = await _sendCommand('ATI');
    if (identification.trim().isEmpty) {
      throw const FormatException(
        'The adapter did not return an ATI response.',
      );
    }
    return identification.trim();
  }

  /// Requests engine RPM (OBD-II Mode 01, PID 0C) and returns revolutions/min.
  Future<double> readRpm() async {
    _requireConnected();
    final response = await _sendCommand('010C');
    return parseRpm(response);
  }

  static double parseRpm(String response) {
    final normalized = response.toUpperCase().replaceAll(
      RegExp(r'[^0-9A-F]'),
      '',
    );
    final match = RegExp(r'410C([0-9A-F]{4})').firstMatch(normalized);
    if (match == null) {
      throw FormatException('No RPM data in adapter response: $response');
    }

    final bytes = int.parse(match.group(1)!, radix: 16);
    return bytes / 4;
  }

  Future<void> disconnect() async {
    if (!_connected) return;
    try {
      await FlutterBluetoothSerial.disconnect();
    } finally {
      _connected = false;
    }
  }

  Future<String> _sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _requireConnected();
    await FlutterBluetoothSerial.write('$command\r');

    final response = StringBuffer();
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      final chunk = await FlutterBluetoothSerial.read();
      if (chunk != null && chunk.isNotEmpty) {
        response.write(chunk);
        if (chunk.contains(_responseTerminator)) break;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    }
    return response.toString().replaceAll(_responseTerminator, '').trim();
  }

  void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Classic Bluetooth ELM327 connections are currently Android-only.',
      );
    }
  }

  void _requireConnected() {
    _requireAndroid();
    if (!_connected) throw StateError('Connect to an adapter first.');
  }
}
