import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/services/obd/elm327_client.dart';

import 'fakes.dart';

void main() {
  late FakeBluetoothTransport transport;
  late Elm327Client client;
  setUp(() async {
    transport = FakeBluetoothTransport();
    client = Elm327Client(transport);
    await client.connect('00:11:22:33:44:55');
  });
  tearDown(() async {
    await client.disconnect();
    await transport.close();
  });
  test('fragmented responses wait for the prompt', () async {
    final response = client.command('010C');
    await waitUntil(() => transport.writes.isNotEmpty);
    transport.receive('7E8 04 41');
    transport.receive(' 0C 1A F8\r');
    transport.receive('>');
    expect(await response, '7E8 04 41 0C 1A F8\r');
  });
  test('concurrent callers use one serialized command queue', () async {
    final first = client.command('010C');
    final second = client.command('010D');
    await waitUntil(() => transport.writes.isNotEmpty);
    expect(transport.writes, ['010C']);
    transport.receive('410C1AF8>');
    await first;
    await waitUntil(() => transport.writes.length == 2);
    transport.receive('410D32>');
    expect(await second, '410D32');
  });
  test(
    'timeouts prevent stale replies being assigned to the next PID',
    () async {
      await expectLater(
        client.command('010C', timeout: const Duration(milliseconds: 20)),
        throwsA(isA<ElmException>()),
      );
      transport.receive('410C1AF8>');
      await expectLater(client.command('010D'), throwsA(isA<ElmException>()));
      expect(transport.writes, ['010C']);
    },
  );
  test('link loss rejects an outstanding command', () async {
    final response = client.command('010C');
    final assertion = expectLater(response, throwsA(isA<ElmException>()));
    await waitUntil(() => transport.writes.isNotEmpty);
    transport.loseConnection();
    await assertion;
  });
  test('initialization sequence and rejected settings', () async {
    transport.automatic = true;
    expect(await client.initialize(), contains('ELM327'));
    expect(transport.writes, ['ATZ', 'ATE0', 'ATL0', 'ATS1', 'ATH1', 'ATSP0']);
    transport.reply = (command) =>
        command == 'ATH1' ? '?' : transport.defaultReply(command);
    await expectLater(client.initialize(), throwsA(isA<ElmException>()));
  });
  test('vehicle-writing commands are rejected', () async {
    await expectLater(client.command('04'), throwsA(isA<ElmException>()));
    await expectLater(client.command('ATMA'), throwsA(isA<ElmException>()));
    await expectLater(client.command('ATSH7E0'), throwsA(isA<ElmException>()));
    expect(transport.writes, isEmpty);
  });
  test('write failure invalidates the command channel', () async {
    transport.onWrite = (_) => Future.error(StateError('Socket closed'));
    await expectLater(client.command('010C'), throwsA(isA<ElmException>()));
    await expectLater(client.command('010D'), throwsA(isA<ElmException>()));
    expect(transport.writes, ['010C']);
  });
  test('link loss is handled while native write is still pending', () async {
    final writing = Completer<void>();
    transport.onWrite = (_) => writing.future;
    final assertion = expectLater(
      client.command('010C'),
      throwsA(isA<ElmException>()),
    );
    await waitUntil(() => transport.writes.isNotEmpty);
    transport.loseConnection();
    await assertion;
    writing.completeError(StateError('Delayed socket failure'));
    await Future<void>.delayed(Duration.zero);
  });
  test('late write failure cannot reject the next parameter', () async {
    final writing = Completer<void>();
    transport.onWrite = (command) =>
        command == '010C' ? writing.future : Future.value();
    final first = client.command('010C');
    await waitUntil(() => transport.writes.isNotEmpty);
    transport.receive('410C1AF8>');
    await first;
    final second = client.command('010D');
    await waitUntil(() => transport.writes.length == 2);
    writing.completeError(StateError('Delayed failure from first command'));
    await Future<void>.delayed(Duration.zero);
    transport.receive('410D32>');
    expect(await second, '410D32');
  });
  test('oversized replies require reconnecting', () async {
    final assertion = expectLater(
      client.command('010C'),
      throwsA(isA<ElmException>()),
    );
    await waitUntil(() => transport.writes.isNotEmpty);
    transport.receive('0' * 32769);
    await assertion;
    await expectLater(client.command('010D'), throwsA(isA<ElmException>()));
  });
  test('reconnect restores command handling after a timeout', () async {
    await expectLater(
      client.command('010C', timeout: const Duration(milliseconds: 20)),
      throwsA(isA<ElmException>()),
    );
    await client.connect('00:11:22:33:44:55');
    transport.automatic = true;
    expect(await client.initialize(), contains('ELM327'));
    expect(await client.command('010C'), contains('41 0C 1A F8'));
  });
}
