import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/obd/elm327_client.dart';
import 'package:autopulse_ai/services/obd/obd_parser.dart';

void main() {
  test('RPM example decodes to 1726', () {
    final response = ObdParser.select(
      ObdParser.responses('010C\r7E8 04 41 0C 1A F8\r', 12, 2),
    );
    expect(response.source, '7E8');
    expect(ObdParser.decode(ObdParameter.rpm, response.bytes), 1726);
  });
  test('compact CAN and headerless replies are supported', () {
    expect(
      ObdParser.select(ObdParser.responses('7E804410C1AF8', 12, 2)).source,
      '7E8',
    );
    expect(ObdParser.select(ObdParser.responses('410D32', 13, 1)).bytes, [50]);
  });
  test('29-bit CAN and ISO headers preserve ECU identity', () {
    expect(
      ObdParser.select(ObdParser.responses('18DAF110 04 41 0C 1A F8', 12, 2))
          .source,
      '18DAF110',
    );
    expect(
      ObdParser.select(ObdParser.responses('48 6B 10 41 05 82 AF', 5, 1))
          .source,
      '486B10',
    );
  });
  test('multiple ECUs do not get mixed', () {
    final replies = ObdParser.responses(
      '7E9 04 41 0C 00 00\r7E8 04 41 0C 1A F8',
      12,
      2,
    );
    expect(ObdParser.select(replies).source, '7E8');
    expect(ObdParser.select(replies, source: '7E9').bytes, [0, 0]);
    expect(
      () => ObdParser.select(replies, source: '7EA'),
      throwsA(isA<ElmException>()),
    );
  });
  test('conflicting same-ECU values are rejected', () {
    expect(
      () => ObdParser.select(ObdParser.responses('410D32\r410D33', 13, 1)),
      throwsA(isA<ElmException>()),
    );
  });
  test('no data, truncated and wrong PID replies are not zeros', () {
    expect(ObdParser.responses('NO DATA', 12, 2), isEmpty);
    expect(ObdParser.responses('410C1A', 12, 2), isEmpty);
    expect(ObdParser.responses('410D32', 12, 2), isEmpty);
  });
  test('bitmap ordering follows PID 1 through 32', () {
    expect(ObdParser.supported([0x80, 0, 0, 1]), {1, 32});
    expect(ObdParser.supported([0, 0, 0, 0]), isEmpty);
    expect(() => ObdParser.supported([1]), throwsA(isA<ElmException>()));
  });
  test('all implemented unit conversions', () {
    expect(ObdParser.decode(ObdParameter.speed, [100]), 100);
    expect(ObdParser.decode(ObdParameter.coolant, [130]), 90);
    expect(ObdParser.decode(ObdParameter.intake, [0]), -40);
    expect(ObdParser.decode(ObdParameter.load, [255]), 100);
    expect(ObdParser.decode(ObdParameter.throttle, [0]), 0);
    expect(ObdParser.decode(ObdParameter.maf, [1, 44]), 3);
    expect(ObdParser.decode(ObdParameter.map, [94]), 94);
    expect(ObdParser.decode(ObdParameter.shortTrim, [128]), 0);
    expect(ObdParser.decode(ObdParameter.longTrim, [0]), -100);
    expect(
      () => ObdParser.decode(ObdParameter.rpm, [1]),
      throwsA(isA<ElmException>()),
    );
  });
}
