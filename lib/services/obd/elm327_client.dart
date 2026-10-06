import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:autopulse_ai/services/obd/bluetooth_transport.dart';

class ElmException implements Exception {
  final String message;
  const ElmException(this.message);
  @override
  String toString() => message;
}

class Elm327Client {
  final BluetoothTransport transport;
  StreamSubscription<BluetoothEvent>? _subscription;
  Completer<String>? _pending;
  Future<void> _queue = Future.value();
  String _buffer = '';
  bool _connected = false;
  bool _synchronized = false;
  int _generation = 0;
  void Function()? onDisconnected;
  Elm327Client(this.transport);

  Future<void> connect(String address) async {
    await disconnect();
    _subscription = transport.events.listen(
      _onEvent,
      onError: (_) => _lostConnection(),
    );
    final generation = _generation;
    try {
      await transport.connect(address).timeout(const Duration(seconds: 18));
      if (generation != _generation) {
        throw const ElmException('Connection cancelled.');
      }
      _connected = true;
      _synchronized = true;
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  void _onEvent(BluetoothEvent event) {
    if (event.type == 'disconnected') {
      _lostConnection();
      return;
    }
    if (event.type != 'data' || event.bytes == null) return;
    // Packets may split a response anywhere. Only the ELM prompt completes it.
    _buffer += ascii.decode(event.bytes!, allowInvalid: true);
    if (_buffer.length > 32768) {
      _fail(const ElmException('Adapter response exceeded the buffer limit.'));
      _synchronized = false;
      _buffer = '';
      return;
    }
    final end = _buffer.indexOf('>');
    if (end >= 0) {
      final response = _buffer.substring(0, end);
      _buffer = _buffer.substring(end + 1);
      final pending = _pending;
      _pending = null;
      if (pending != null && !pending.isCompleted) pending.complete(response);
    }
  }

  Future<String> command(
    String command, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    final generation = _generation;
    final result = _queue.then((_) => _exchange(command, timeout, generation));
    // A rejected caller must not poison the queue for subsequent callers.
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<String> _exchange(
    String command,
    Duration timeout,
    int generation,
  ) async {
    if (!_connected || !_synchronized || generation != _generation) {
      throw const ElmException(
        'Adapter is disconnected or requires reconnection.',
      );
    }
    const initializationCommands = {
      'ATZ',
      'ATE0',
      'ATL0',
      'ATS1',
      'ATH1',
      'ATSP0',
    };
    if (!initializationCommands.contains(command) &&
        !RegExp(r'^01[0-9A-F]{2}$').hasMatch(command)) {
      throw const ElmException(
        'Only initialization and read-only Mode 01 commands are allowed.',
      );
    }
    _buffer = '';
    final pending = Completer<String>();
    _pending = pending;
    // Listen immediately, even if the platform's write completion is delayed.
    unawaited(
      transport
          .write(Uint8List.fromList(ascii.encode('$command\r')))
          .catchError((Object _) {
            if (identical(_pending, pending)) {
              _synchronized = false;
              _fail(const ElmException('Could not send command to adapter.'));
            }
          }),
    );
    try {
      return await pending.future.timeout(timeout);
    } on TimeoutException {
      // A late response cannot safely be assigned to another PID. Require reconnection.
      _synchronized = false;
      _pending = null;
      throw const ElmException(
        'Adapter response timed out. Reconnect to resume.',
      );
    }
  }

  Future<String> initialize() async {
    final identity = await command('ATZ', timeout: const Duration(seconds: 8));
    if (!identity.toUpperCase().contains('ELM') &&
        !identity.toUpperCase().contains('OBD')) {
      throw const ElmException(
        'The selected device did not identify as an OBD adapter.',
      );
    }
    for (final setting in ['ATE0', 'ATL0', 'ATS1', 'ATH1', 'ATSP0']) {
      final response = await command(setting);
      if (!response.toUpperCase().contains('OK')) {
        throw ElmException('Adapter rejected $setting.');
      }
    }
    return identity.trim();
  }

  void _fail(ElmException error) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.completeError(error);
  }

  void _lostConnection() {
    _connected = false;
    _synchronized = false;
    _generation++;
    _fail(const ElmException('Bluetooth connection was lost.'));
    onDisconnected?.call();
  }

  Future<void> disconnect() async {
    _connected = false;
    _synchronized = false;
    _generation++;
    _fail(const ElmException('Adapter disconnected.'));
    await _subscription?.cancel();
    _subscription = null;
    await transport.disconnect();
    _buffer = '';
  }
}
