import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/services/recording_analysis.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('ELM bytes flow through all PIDs into SQLite, analysis and CSV, then reconnect cleanly', () async {
    final transport = FakeBluetoothTransport()..automatic = true;
    final store = SqliteObdRecordingRepository(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      owner: () => null,
    );
    final controller = ObdController(
      transport: transport,
      repository: store,
      observeLifecycle: false,
    );
    controller.setVehicle(
      const Vehicle(make: 'Synthetic', model: 'Demo test', year: 2020),
    );
    const device = ObdDevice(
      name: 'Synthetic test adapter',
      address: '00:11:22:33:44:55',
    );
    try {
      await controller.connect(device);
      await controller.startRecording();
      await waitUntil(() => controller.savedSamples >= 10);
      await controller.stopRecording();
      final recording = (await store.listRecordings(null)).single;
      expect(recording.endedAt, isNotNull);
      expect(recording.sampleCount, controller.savedSamples);
      final rows = await store.samples(recording.id);
      expect(
        rows.map((row) => row.sample.parameter).toSet(),
        ObdParameter.values.toSet(),
      );
      for (final row in rows) {
        expect(row.sample.status, ObdSampleStatus.valid);
        expect(row.sample.source, '7E8');
        expect(row.sample.value, isNotNull);
        expect(row.sample.receivedAt.isBefore(row.sample.requestedAt), isFalse);
      }
      final quality = await analyzeRecording(store, recording.id);
      expect(quality.length, 10);
      expect(quality.values.every((pid) => pid.total == pid.valid), isTrue);
      final csv = StringBuffer();
      await exportRecordingCsv(
        store,
        recording,
        (chunk) async => csv.write(chunk),
      );
      expect(
        csv.toString().split('\n').where((line) => line.isNotEmpty).length,
        recording.sampleCount + 1,
      );
      expect(csv.toString(), contains('1726.0'));
      expect(controller.rpmHistory, isNotEmpty);
      await controller.disconnect();
      expect(controller.isReady, isFalse);
      await controller.connect(device);
      expect(controller.rpmHistory, isEmpty);
      expect(controller.isRecording, isFalse);
      // Backgrounding the app must stop foreground-only acquisition.
      await controller.startRecording();
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await waitUntil(
        () =>
            !controller.isReady &&
            !controller.isRecording &&
            !controller.recordingBusy,
      );
      expect(controller.isRecording, isFalse);
      expect(
        (await store.listRecordings(null)).every((run) => run.endedAt != null),
        isTrue,
      );
    } finally {
      await controller.disconnect();
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      await transport.close();
      await store.close();
    }
  });
}
