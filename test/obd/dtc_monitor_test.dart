import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/obd_dtc.dart';
import 'package:autopulse_ai/services/obd/dtc_monitor.dart';
import 'package:autopulse_ai/services/obd/elm327_client.dart';

import 'fakes.dart';

void main() {
  late FakeBluetoothTransport transport;
  late Elm327Client client;
  late DtcMonitor monitor;
  var ready = true;
  setUp(() async {
    transport = FakeBluetoothTransport()..automatic = true;
    client = Elm327Client(transport);
    await client.connect('test');
    ready = true;
    monitor = DtcMonitor(
      client: client,
      isReady: () => ready,
      ecuSource: () => '7E8',
    );
  });
  tearDown(() async {
    monitor.dispose();
    await client.disconnect();
    await transport.close();
  });
  test('reads MIL and all three categories using read-only services', () async {
    transport.reply = (command) => switch (command) {
      '0101' => '7E8 06 41 01 81 00 00 00',
      '03' => '7E8 04 43 01 01 33',
      _ => transport.defaultReply(command),
    };
    await monitor.scan();
    expect(transport.writes, ['0101', '03', '07', '0A']);
    expect(monitor.milOn, isTrue);
    expect(monitor.storedCount, 1);
    expect(monitor.snapshot(DtcKind.stored).codes.single.code, 'P0133');
    expect(monitor.alertCodes, ['P0133']);
    expect(monitor.alertRevision, 1);
    expect(monitor.due, isFalse);
    await monitor.scan();
    expect(monitor.alertRevision, 1);
  });
  test(
    'unavailable and malformed responses retain previous successful codes',
    () async {
      transport.reply = (command) => command == '03'
          ? '7E8 04 43 01 03 00'
          : transport.defaultReply(command);
      await monitor.scan();
      final readAt = monitor.snapshot(DtcKind.stored).readAt;
      transport.reply = (_) => 'NO DATA';
      await monitor.scan();
      expect(monitor.snapshot(DtcKind.stored).codes.single.code, 'P0300');
      expect(monitor.snapshot(DtcKind.stored).readAt, readAt);
      expect(monitor.snapshot(DtcKind.stored).error, isNotNull);
      expect(monitor.milError, isNotNull);
      expect(monitor.alertRevision, 1);
    },
  );
  test(
    'a successful empty reply removes codes without a false alert',
    () async {
      transport.reply = (command) => command == '03'
          ? '7E8 04 43 01 03 00'
          : transport.defaultReply(command);
      await monitor.scan();
      transport.reply = null;
      await monitor.scan();
      expect(monitor.snapshot(DtcKind.stored).codes, isEmpty);
      expect(monitor.snapshot(DtcKind.stored).error, isNull);
      expect(monitor.alertRevision, 1);
      transport.reply = (command) => command == '03'
          ? '7E8 04 43 01 03 00'
          : transport.defaultReply(command);
      await monitor.scan();
      expect(monitor.alertRevision, 2);
    },
  );
  test(
    'disconnect cancels late scan results and prevents overlapping scans',
    () async {
      final release = Completer<void>();
      transport.onWrite = (_) => release.future;
      final first = monitor.scan();
      await waitUntil(() => transport.writes.isNotEmpty);
      await monitor.scan();
      expect(transport.writes, ['0101']);
      ready = false;
      monitor.disconnected();
      release.complete();
      await first;
      expect(monitor.scanning, isFalse);
      expect(monitor.milReadAt, isNull);
      expect(monitor.snapshot(DtcKind.stored).readAt, isNull);
    },
  );
  test(
    'reset discards old context and permits a new connection alert',
    () async {
      transport.reply = (command) => command == '03'
          ? '7E8 04 43 01 03 00'
          : transport.defaultReply(command);
      await monitor.scan();
      monitor.reset();
      expect(monitor.alertCodes, isEmpty);
      expect(monitor.milReadAt, isNull);
      await monitor.scan();
      expect(monitor.alertRevision, 2);
    },
  );
  test('unconnected scans never write commands', () async {
    ready = false;
    await monitor.scan();
    expect(transport.writes, isEmpty);
  });
}
