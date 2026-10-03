import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/obd/elm327_client.dart';

class PidResponse {
  final String source;
  final List<int> bytes;
  const PidResponse(this.source, this.bytes);
}

class ObdParser {
  static List<PidResponse> responses(String raw, int pid, int count) {
    final pidHex = pid.toRadixString(16).padLeft(2, '0').toUpperCase();
    final pattern = RegExp('41$pidHex([0-9A-F]{${count * 2}})');
    final results = <PidResponse>[];
    for (final original in raw.toUpperCase().split(RegExp(r'[\r\n]+'))) {
      final line = original.replaceFirst(RegExp(r'^\s*\d+:\s*'), '').trim();
      if (!RegExp(r'^[0-9A-F\s]+$').hasMatch(line)) continue;
      final compact = line.replaceAll(RegExp(r'\s+'), '');
      final match = pattern.firstMatch(compact);
      if (match == null) continue;
      final prefix = compact.substring(0, match.start);
      final first = line.split(RegExp(r'\s+')).first;
      // Exclude CAN length bytes from the source identity; retain ISO header bytes.
      final source = prefix.isEmpty
          ? 'default'
          : first.length == 3 || prefix.length == 5
          ? prefix.substring(0, 3)
          : first.length == 8 || prefix.length == 10
          ? prefix.substring(0, 8)
          : prefix.length >= 6
          ? prefix.substring(0, 6)
          : prefix;
      final hex = match.group(1)!;
      results.add(
        PidResponse(source, [
          for (var i = 0; i < hex.length; i += 2)
            int.parse(hex.substring(i, i + 2), radix: 16),
        ]),
      );
    }
    return results;
  }

  static PidResponse select(List<PidResponse> replies, {String? source}) {
    final candidates = source == null
        ? replies
        : replies.where((r) => r.source == source).toList();
    if (candidates.isEmpty) {
      throw const ElmException('No matching ECU response.');
    }
    final chosen = source == null
        ? candidates.firstWhere(
            (r) => r.source == '7E8',
            orElse: () => candidates.first,
          )
        : candidates.first;
    if (candidates
        .where((r) => r.source == chosen.source)
        .any((r) => r.bytes.join(',') != chosen.bytes.join(','))) {
      throw const ElmException('Conflicting replies from the selected ECU.');
    }
    return chosen;
  }

  static Set<int> supported(List<int> bytes, {int base = 0}) {
    if (bytes.length != 4) {
      throw const ElmException('Invalid supported-PID bitmap.');
    }
    final mask =
        (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    return {
      for (var bit = 0; bit < 32; bit++)
        if ((mask & (1 << (31 - bit))) != 0) base + bit + 1,
    };
  }

  static double decode(ObdParameter parameter, List<int> bytes) {
    if (bytes.length != parameter.byteCount) {
      throw const ElmException('Invalid PID payload length.');
    }
    final a = bytes[0];
    return switch (parameter) {
      ObdParameter.rpm => (256 * a + bytes[1]) / 4,
      ObdParameter.speed || ObdParameter.map => a.toDouble(),
      ObdParameter.coolant || ObdParameter.intake => a - 40.0,
      ObdParameter.load || ObdParameter.throttle => a * 100 / 255,
      ObdParameter.maf => (256 * a + bytes[1]) / 100,
      ObdParameter.shortTrim || ObdParameter.longTrim => (a - 128) * 100 / 128,
    };
  }
}
