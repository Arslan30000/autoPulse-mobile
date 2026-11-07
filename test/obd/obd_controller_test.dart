import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

import 'fakes.dart';

void main() {
  late FakeBluetoothTransport transport;
  late MemoryRecordingRepository repository;
  late ObdController controller;
  const device = ObdDevice(name: 'ELM327', address: '00:11:22:33:44:55');
  setUp(() {
    transport = FakeBluetoothTransport()..automatic = true;
    repository = MemoryRecordingRepository();
    controller = ObdController(
      transport: transport,
      repository: repository,
      observeLifecycle: false,
    );
  });
  tearDown(() async {
    await controller.disconnect();
    controller.dispose();
    await transport.close();
  });
  test('permission denial does not connect', () async {
    transport.allowed = false;
    await controller.loadDevices();
    expect(controller.error, contains('denied'));
    expect(controller.devices, isEmpty);
  });
  test(
    'discovers supported parameters and publishes real decoded values',
    () async {
      await controller.connect(device);
      await waitUntil(() => controller.samples.containsKey(ObdParameter.rpm));
      expect(controller.status, ObdConnectionStatus.ready);
      expect(controller.supported.length, ObdParameter.values.length);
      expect(controller.samples[ObdParameter.rpm]!.value, 1726);
      expect(controller.ecuSource, '7E8');
    },
  );
  test('NO DATA retains null with an explicit quality flag', () async {
    transport.reply = (command) =>
        command == '010C' ? 'NO DATA' : transport.defaultReply(command);
    await controller.connect(device);
    await waitUntil(() => controller.samples.containsKey(ObdParameter.rpm));
    expect(controller.samples[ObdParameter.rpm]!.value, isNull);
    expect(
      controller.samples[ObdParameter.rpm]!.status,
      ObdSampleStatus.noData,
    );
    expect(controller.rpmHistory.single.status, ObdSampleStatus.noData);
    expect(controller.rpmHistory.single.value, isNull);
  });
  test(
    'recording saves parameter samples and finalizes on disconnect',
    () async {
      await controller.connect(device);
      await controller.startRecording();
      await waitUntil(() => repository.samples.isNotEmpty);
      await controller.disconnect();
      expect(controller.isRecording, isFalse);
      expect(repository.finishes, 1);
      expect(
        repository.samples.first.receivedAt.isBefore(
          repository.samples.first.requestedAt,
        ),
        isFalse,
      );
    },
  );
  test(
    'recording failures are surfaced without inventing saved samples',
    () async {
      repository.failWrites = true;
      await controller.connect(device);
      await controller.startRecording();
      await waitUntil(() => controller.storageError != null);
      expect(controller.savedSamples, 0);
      expect(controller.isReady, isTrue);
    },
  );
  test('link loss stops the session and changes connection status', () async {
    await controller.connect(device);
    await controller.startRecording();
    transport.loseConnection();
    await waitUntil(() => repository.finishes == 1);
    expect(controller.status, ObdConnectionStatus.disconnected);
    expect(controller.isRecording, isFalse);
  });

  test(
    'a cancelled recording start cannot attach to a reconnected adapter',
    () async {
      final delayed = _DelayedRecordingRepository();
      controller.dispose();
      controller = ObdController(
        transport: transport,
        repository: delayed,
        observeLifecycle: false,
      );
      await controller.connect(device);
      final starting = controller.startRecording();
      await waitUntil(() => delayed.startCalled);
      await controller.disconnect();
      await controller.connect(device);
      delayed.startGate.complete(42);
      await starting;
      expect(controller.isReady, isTrue);
      expect(controller.isRecording, isFalse);
      expect(delayed.finishes, 1);
    },
  );

  test('disconnect waits for a recording stop already in progress', () async {
    final delayed = _DelayedRecordingRepository()..startGate.complete(42);
    controller.dispose();
    controller = ObdController(
      transport: transport,
      repository: delayed,
      observeLifecycle: false,
    );
    await controller.connect(device);
    await controller.startRecording();
    delayed.finishGate = Completer<void>();
    final stopping = controller.stopRecording();
    var disconnected = false;
    final disconnecting = controller.disconnect().then(
      (_) => disconnected = true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final returnedEarly = disconnected;
    delayed.finishGate!.complete();
    await Future.wait([stopping, disconnecting]);
    expect(returnedEarly, isFalse);
    expect(delayed.finishes, 1);
  });

  test(
    'connection is busy immediately and ignores a duplicate connect',
    () async {
      controller.dispose();
      transport = _BlockingDisconnectTransport()..automatic = true;
      final blocking = transport as _BlockingDisconnectTransport;
      controller = ObdController(
        transport: transport,
        repository: repository,
        observeLifecycle: false,
      );
      final first = controller.connect(device);
      final wasBusy = controller.isBusy;
      final second = controller.connect(device);
      blocking.gate.complete();
      await Future.wait([first, second]);
      expect(wasBusy, isTrue);
      expect(blocking.connectCalls, 1);
      expect(controller.isReady, isTrue);
    },
  );

  test(
    'disconnect cancels connection even during initial socket cleanup',
    () async {
      controller.dispose();
      transport = _BlockingDisconnectTransport()..automatic = true;
      final blocking = transport as _BlockingDisconnectTransport;
      controller = ObdController(
        transport: transport,
        repository: repository,
        observeLifecycle: false,
      );
      final connecting = controller.connect(device);
      final disconnecting = controller.disconnect();
      blocking.gate.complete();
      await Future.wait([connecting, disconnecting]);
      expect(controller.status, ObdConnectionStatus.disconnected);
      expect(blocking.connectCalls, 0);
    },
  );

  test(
    'a non-ELM device fails initialization without starting polling',
    () async {
      transport.reply = (command) => command == 'ATZ'
          ? 'Unrelated serial device'
          : transport.defaultReply(command);
      await controller.connect(device);
      expect(controller.status, ObdConnectionStatus.error);
      expect(controller.error, contains('did not identify'));
      expect(controller.samples, isEmpty);
      await controller.startRecording();
      expect(controller.isRecording, isFalse);
    },
  );

  test('an ECU with none of the implemented PIDs does not show LIVE', () async {
    transport.reply = (command) => command == '0100'
        ? '7E8 06 41 00 00 00 00 00'
        : transport.defaultReply(command);
    await controller.connect(device);
    expect(controller.status, ObdConnectionStatus.error);
    expect(controller.error, contains('none of the supported'));
    expect(controller.isReady, isFalse);
  });

  test('a malformed RPM packet is missing data rather than a zero or guessed reading', () async {
    transport.reply = (command) =>
        command == '010C' ? '7E8 04 41 0C 1A' : transport.defaultReply(command);
    await controller.connect(device);
    await waitUntil(() => controller.samples.containsKey(ObdParameter.rpm));
    expect(
      controller.samples[ObdParameter.rpm]!.status,
      ObdSampleStatus.invalid,
    );
    expect(controller.samples[ObdParameter.rpm]!.value, isNull);
    expect(controller.isReady, isTrue);
  });

  test('unsupported PIDs are never requested from the ECU', () async {
    transport.reply = (command) => command == '0100'
        ? '7E8 06 41 00 00 18 00 00'
        : transport.defaultReply(command);
    await controller.connect(device);
    await waitUntil(() => controller.samples.length == 2);
    expect(controller.supported, {ObdParameter.rpm, ObdParameter.speed});
    expect(
      transport.writes
          .where((command) => command.startsWith('01') && command != '0100')
          .toSet(),
      {'010C', '010D'},
    );
  });
}

class _BlockingDisconnectTransport extends FakeBluetoothTransport {
  final gate = Completer<void>();
  int connectCalls = 0;
  @override
  Future<void> disconnect() => gate.future;
  @override
  Future<void> connect(String address) async {
    connectCalls++;
  }
}

class _DelayedRecordingRepository extends MemoryRecordingRepository {
  final startGate = Completer<int>();
  Completer<void>? finishGate;
  bool startCalled = false;
  @override
  Future<int> start(Vehicle vehicle, ObdDevice device) {
    startCalled = true;
    return startGate.future;
  }

  @override
  Future<void> finish(int sessionId) async {
    await finishGate?.future;
    await super.finish(sessionId);
  }
}
