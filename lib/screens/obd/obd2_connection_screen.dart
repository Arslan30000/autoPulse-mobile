import 'dart:async';

import 'package:flutter/material.dart';

import 'package:autopulse_ai/services/obd/elm327_service.dart';

class Obd2ConnectionScreen extends StatefulWidget {
  const Obd2ConnectionScreen({super.key});

  @override
  State<Obd2ConnectionScreen> createState() => _Obd2ConnectionScreenState();
}

class _Obd2ConnectionScreenState extends State<Obd2ConnectionScreen> {
  final Elm327Service _service = Elm327Service();
  List<ObdDevice> _devices = const [];
  ObdDevice? _connectedDevice;
  String _status =
      'Pair the ELM327 adapter in Android Bluetooth settings first.';
  String? _adapterInfo;
  double? _rpm;
  bool _busy = false;

  Future<void> _loadPairedDevices() async {
    await _runBusy(() async {
      final devices = await _service.getPairedDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _status = devices.isEmpty
            ? 'No paired devices found. Pair the adapter in Android settings, then refresh.'
            : 'Choose your paired ELM327 adapter to connect.';
      });
    });
  }

  Future<void> _connect(ObdDevice device) async {
    await _runBusy(() async {
      setState(() {
        _status = 'Connecting to ${device.name}…';
        _adapterInfo = null;
        _rpm = null;
      });
      await _service.connect(device);
      if (!mounted) return;
      setState(() {
        _connectedDevice = device;
        _status = 'Connected. Initializing the ELM327…';
      });

      try {
        final adapterInfo = await _service.initializeAdapter();
        if (!mounted) return;
        setState(() {
          _adapterInfo = adapterInfo;
          _status = 'Adapter ready. Request engine RPM to confirm OBD-II data.';
        });
      } on Object catch (error) {
        if (!mounted) return;
        setState(() => _status = 'Connected, but adapter setup failed: $error');
      }
    });
  }

  Future<void> _readRpm() async {
    await _runBusy(() async {
      final rpm = await _service.readRpm();
      if (!mounted) return;
      setState(() {
        _rpm = rpm;
        _status = 'Received OBD-II Mode 01 PID 0C response.';
      });
    });
  }

  Future<void> _disconnect() async {
    await _runBusy(() async {
      await _service.disconnect();
      if (!mounted) return;
      setState(() {
        _connectedDevice = null;
        _adapterInfo = null;
        _rpm = null;
        _status = 'Disconnected from the OBD-II adapter.';
      });
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'Bluetooth error: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_service.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _connectedDevice != null;
    return Scaffold(
      appBar: AppBar(title: const Text('OBD-II Bluetooth')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'Connected' : 'Not connected',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_connectedDevice case final device?) ...[
                      const SizedBox(height: 8),
                      Text('${device.name} • ${device.address}'),
                    ],
                    if (_adapterInfo case final info?) ...[
                      const SizedBox(height: 8),
                      Text('Adapter: $info'),
                    ],
                    if (_rpm case final rpm?) ...[
                      const SizedBox(height: 8),
                      Text('Engine RPM: ${rpm.toStringAsFixed(0)} rpm'),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Android only • Classic Bluetooth ELM327 SPP • Android 8 or newer',
              ),
            ),
            const SizedBox(height: 12),
            if (!connected)
              FilledButton.icon(
                onPressed: _busy ? null : _loadPairedDevices,
                icon: const Icon(Icons.bluetooth_searching_rounded),
                label: const Text('Load paired devices'),
              )
            else ...[
              FilledButton.icon(
                onPressed: _busy ? null : _readRpm,
                icon: const Icon(Icons.speed_rounded),
                label: const Text('Read engine RPM'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _disconnect,
                icon: const Icon(Icons.bluetooth_disabled_rounded),
                label: const Text('Disconnect'),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (!connected && _devices.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Paired devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final device in _devices)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth_rounded),
                    title: Text(device.name),
                    subtitle: Text(device.address),
                    trailing: IconButton(
                      tooltip: 'Connect to ${device.name}',
                      onPressed: _busy ? null : () => _connect(device),
                      icon: const Icon(Icons.link_rounded),
                    ),
                    onTap: _busy ? null : () => _connect(device),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
