import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/obd.dart';
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
}
