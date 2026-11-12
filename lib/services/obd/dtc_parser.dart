import 'package:autopulse_ai/models/obd_dtc.dart';

/// Decodes read-only OBD DTC responses. Invalid/incomplete data is never an
/// empty successful scan. CAN transport frames are reassembled per ECU.
class DtcParser {
  static String decode(int a, int b) =>
      '${'PCBU'[(a >> 6) & 3]}${(a >> 4) & 3}'
              '${(a & 15).toRadixString(16)}${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  static List<ObdDtc> parse(String raw, DtcKind kind, DateTime readAt) {
    final text = raw.toUpperCase();
    if (RegExp(r'NO DATA|STOPPED|ERROR|UNABLE|BUS INIT|\?').hasMatch(text)) {
      throw const FormatException('ECU response unavailable.');
    }
    final messages = <({String source, List<int> bytes, bool can})>[];
    final assembling = <String, _Assembly>{};
    for (var line in text.replaceAll('>', '').split(RegExp(r'[\r\n]+'))) {
      line = line.trim();
      if (line.isEmpty ||
          line == kind.command ||
          line.startsWith('SEARCHING')) {
        continue;
      }
      String source = 'ECU';
      var can = false;
      final header = RegExp(r'^([0-9A-F]{3}|[0-9A-F]{8})\s+').firstMatch(line);
      if (header != null) {
        source = header.group(1)!;
        can = true;
        line = line.substring(header.end);
      } else if (RegExp(r'^[0-9A-F]{3}(?:[0-9A-F]{2})+$').hasMatch(line)) {
        source = line.substring(0, 3);
        can = true;
        line = line.substring(3);
      }
      final compact = line.replaceAll(RegExp(r'\s+'), '');
      if (!RegExp(r'^(?:[0-9A-F]{2})+$').hasMatch(compact)) {
        throw const FormatException('Unrecognized DTC response format.');
      }
      var bytes = [
        for (var i = 0; i < compact.length; i += 2)
          int.parse(compact.substring(i, i + 2), radix: 16),
      ];
      if (!can && bytes.length >= 4 && bytes[0] == 0x48) {
        source = bytes
            .take(3)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase();
        final frame = bytes;
        bytes = bytes.sublist(3);
        // Some adapters include the ISO checksum, others remove it.
        if ((bytes.length - 1).isOdd) {
          if ((frame.take(frame.length - 1).fold<int>(0, (a, b) => a + b) &
                  255) !=
              frame.last) {
            throw const FormatException('Invalid ISO response checksum.');
          }
          bytes = bytes.sublist(0, bytes.length - 1);
        }
      }
      if (can) {
        final type = bytes.first >> 4;
        if (type == 0) {
          final length = bytes.first & 15;
          if (length == 0 || bytes.length < length + 1) {
            throw const FormatException('Truncated CAN response.');
          }
          bytes = bytes.sublist(1, length + 1);
        } else if (type == 1) {
          if (bytes.length < 3 || assembling.containsKey(source)) {
            throw const FormatException('Invalid first CAN frame.');
          }
          final length = ((bytes[0] & 15) << 8) | bytes[1];
          if (length <= bytes.length - 2) {
            throw const FormatException('Invalid CAN message length.');
          }
          assembling[source] = _Assembly(length, bytes.sublist(2));
          continue;
        } else if (type == 2) {
          final assembly = assembling[source];
          if (assembly == null || (bytes[0] & 15) != assembly.sequence) {
            throw const FormatException('Missing or out-of-order CAN frame.');
          }
          assembly.sequence = (assembly.sequence + 1) & 15;
          assembly.bytes.addAll(bytes.skip(1));
          if (assembly.bytes.length < assembly.length) continue;
          bytes = assembly.bytes.take(assembly.length).toList();
          assembling.remove(source);
        } else {
          throw const FormatException('Unexpected CAN frame.');
        }
      }
      messages.add((source: source, bytes: bytes, can: can));
    }
    if (assembling.isNotEmpty || messages.isEmpty) {
      throw const FormatException('Incomplete DTC response.');
    }
    final results = <String, ObdDtc>{};
    for (final message in messages) {
      final bytes = message.bytes;
      if (bytes.isEmpty || bytes.first != kind.response) {
        throw const FormatException(
          'ECU did not return the requested DTC service.',
        );
      }
      var data = bytes.sublist(1);
      if (data.isEmpty) {
        throw const FormatException('Missing DTC payload.');
      }
      // CAN adds a count; headerless adapters can also expose that payload.
      if (message.can || data.length.isOdd) {
        if (data.isEmpty) throw const FormatException('Missing DTC count.');
        final count = data.first;
        data = data.sublist(1);
        if (data.length < count * 2 ||
            data.skip(count * 2).any((b) => b != 0)) {
          throw const FormatException('DTC count does not match response.');
        }
        data = data.take(count * 2).toList();
      }
      if (data.length.isOdd) {
        throw const FormatException('Incomplete DTC bytes.');
      }
      for (var i = 0; i < data.length; i += 2) {
        if (data[i] == 0 && data[i + 1] == 0) continue;
        final dtc = ObdDtc(
          code: decode(data[i], data[i + 1]),
          kind: kind,
          source: message.source,
          readAt: readAt,
        );
        results[dtc.identity] = dtc;
      }
    }
    return results.values.toList();
  }
}

class _Assembly {
  _Assembly(this.length, this.bytes);
  final int length;
  final List<int> bytes;
  int sequence = 1;
}
