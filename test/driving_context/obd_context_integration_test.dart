import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/driving_context.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

import '../obd/fakes.dart';

void main() {
  test(
    'existing ELM polling updates context and vehicle/disconnect clear it',
    () async {
      final transport = FakeBluetoothTransport()..automatic = true;
      final obd = ObdController(
        transport: transport,
        repository: MemoryRecordingRepository(),
        observeLifecycle: false,
      );
      try {
        await obd.connect(const ObdDevice(name: 'ELM', address: 'test'));
        await waitUntil(
          () => obd.drivingContext.current.state.isOperating,
          timeout: const Duration(seconds: 15),
        );
        expect(obd.drivingContext.current.state, DrivingState.highwayCruising);
        expect(
          transport.writes.toSet(),
          everyElement(
            isIn({
              'ATZ',
              'ATE0',
              'ATL0',
              'ATS1',
              'ATH1',
              'ATSP0',
              '0100',
              '0101',
              '03',
              '07',
              '0A',
              ...ObdParameter.values.map((p) => p.command),
            }),
          ),
        );
        obd.setVehicle(
          const Vehicle(
            id: 'different-vehicle',
            make: 'Toyota',
            model: 'Yaris',
            year: 2020,
          ),
        );
        expect(obd.drivingContext.current.state, DrivingState.reading);
        await obd.disconnect();
        expect(obd.drivingContext.current.state, DrivingState.disconnected);
      } finally {
        await obd.disconnect();
        obd.dispose();
        await transport.close();
      }
    },
  );
}
