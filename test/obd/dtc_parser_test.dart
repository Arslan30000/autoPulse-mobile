import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/obd_dtc.dart';
import 'package:autopulse_ai/services/obd/dtc_parser.dart';

void main() {
  final now = DateTime.utc(2026, 11, 12);
  List<ObdDtc> parse(String raw, [DtcKind kind = DtcKind.stored]) =>
      DtcParser.parse(raw, kind, now);

  test('decodes P, C, B, U families and hexadecimal digits', () {
    expect(DtcParser.decode(0x01, 0x33), 'P0133');
    expect(DtcParser.decode(0x52, 0x34), 'C1234');
    expect(DtcParser.decode(0x8A, 0xBC), 'B0ABC');
    expect(DtcParser.decode(0xD0, 0x16), 'U1016');
  });
  test('CAN count is not part of the code; zero padding is ignored', () {
    final codes = parse('03\r7E8 04 43 01 01 33 00 00 00\r>');
    expect(codes.single.code, 'P0133');
    expect(codes.single.source, '7E8');
    expect(codes.single.readAt, now);
    expect(parse('7E8 02 43 00'), isEmpty);
  });
  test('supports legacy payloads and ISO header with valid checksum', () {
    expect(parse('43 01 33 00 00 00 00').single.code, 'P0133');
    expect(parse('48 6B 10 43 01 33 00 00 00 00 3A').single.code, 'P0133');
    expect(parse('43 00 00 00 00 00 00'), isEmpty);
  });
  test('reassembles interleaved multi-frame CAN replies per ECU', () {
    final codes = parse(
      '7E8 10 0A 43 04 01 33 03 00\r'
      '7E9 04 43 01 01 71\r'
      '7E8 21 04 20 C1 23 00 00 00',
    );
    expect(codes.map((c) => c.code), [
      'P0171',
      'P0133',
      'P0300',
      'P0420',
      'U0123',
    ]);
    expect(codes.first.source, '7E9');
  });
  test('supports 29-bit CAN and compact 11-bit CAN', () {
    expect(parse('18DAF110 04 43 01 03 00').single.source, '18DAF110');
    expect(parse('7E80443010300').single.code, 'P0300');
  });
  test('pending and permanent services keep their category', () {
    expect(
      parse('7E8 04 47 01 01 71', DtcKind.pending).single.kind,
      DtcKind.pending,
    );
    expect(parse('7E8 04 4A 01 04 20', DtcKind.permanent).single.code, 'P0420');
  });
  test('duplicates are removed within one ECU, retained across ECUs', () {
    final codes = parse(
      '7E8 04 43 01 01 33\r7E8 04 43 01 01 33\r7E9 04 43 01 01 33',
    );
    expect(codes.length, 2);
  });
  for (final response in [
    '43',
    '7E8 01 43',
    'NO DATA',
    '?',
    '',
    '7E8 03 7F 03 11',
    '7E8 04 47 01 01 33',
    '7E8 04 43 02 01 33',
    '7E8 04 43 01 01',
    '7E8 10 0A 43 04 01 33 03 00',
    '7E8 10 0A 43 04 01 33 03 00\r7E8 22 04 20 C1 23 00 00 00',
    '48 6B 10 43 01 33 00 00 00 00 FF',
  ]) {
    test('rejects unavailable or malformed response: $response', () {
      expect(() => parse(response), throwsFormatException);
    });
  }
}
