import 'package:autopulse_ai/services/obd/elm327_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Elm327Service.parseRpm', () {
    test('decodes an OBD-II Mode 01 PID 0C response', () {
      expect(Elm327Service.parseRpm('41 0C 1A F8>'), 1726);
    });

    test('rejects responses without an RPM PID payload', () {
      expect(
        () => Elm327Service.parseRpm('NO DATA>'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
