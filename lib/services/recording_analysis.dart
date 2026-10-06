import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';

class PidQuality {
  int total = 0;
  int valid = 0;
  int latencyTotal = 0;
  int maxLatencyMs = 0;
  int clockDiscontinuities = 0;
  Duration longestGap = Duration.zero;
  DateTime? _first;
  DateTime? _last;
  final Map<ObdSampleStatus, int> counts = {};
  double get meanLatencyMs => total == 0 ? 0 : latencyTotal / total;
  double? get observedHz {
    if (total < 2 || clockDiscontinuities > 0) return null;
    final seconds = _last!.difference(_first!).inMicroseconds / 1000000;
    return seconds > 0 ? (total - 1) / seconds : null;
  }

  void add(ObdSample sample) {
    total++;
    counts.update(sample.status, (n) => n + 1, ifAbsent: () => 1);
    if (sample.status == ObdSampleStatus.valid && sample.value != null) valid++;
    latencyTotal += sample.latencyMs;
    if (sample.latencyMs > maxLatencyMs) maxLatencyMs = sample.latencyMs;
    _first ??= sample.receivedAt;
    if (_last != null) {
      final gap = sample.receivedAt.difference(_last!);
      if (gap.isNegative) clockDiscontinuities++;
      if (gap > longestGap) longestGap = gap;
    }
    _last = sample.receivedAt;
  }
}

Future<Map<ObdParameter, PidQuality>> analyzeRecording(
  RecordingStore store,
  int id,
) async {
  final result = <ObdParameter, PidQuality>{};
  var cursor = 0;
  while (true) {
    final page = await store.samples(id, afterId: cursor);
    if (page.isEmpty) break;
    for (final row in page) {
      (result[row.sample.parameter] ??= PidQuality()).add(row.sample);
    }
    cursor = page.last.id;
  }
  return result;
}

/// Text fields are quoted and spreadsheet formulas neutralized; numbers remain numbers.
String csvCell(Object? value) {
  if (value == null) return '';
  if (value is num) return value.toString();
  var text = value.toString();
  if (RegExp(r'^\s*[=+\-@]').hasMatch(text) ||
      text.startsWith('\t') ||
      text.startsWith('\r')) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}

/// Bounded-memory export: the caller can stream chunks directly to a file.
Future<void> exportRecordingCsv(
  RecordingStore store,
  ObdRecording recording,
  Future<void> Function(String chunk) write,
) async {
  await write(
    'session_id,sample_id,vehicle,adapter,pid,label,value,unit,quality,requested_at_utc,received_at_utc,latency_ms,ecu_source\r\n',
  );
  var cursor = 0;
  while (true) {
    final page = await store.samples(recording.id, afterId: cursor);
    if (page.isEmpty) break;
    final buffer = StringBuffer();
    for (final row in page) {
      final sample = row.sample;
      buffer.writeln(
        [
          recording.cloudId,
          row.id,
          recording.vehicleName,
          recording.adapterName,
          sample.parameter.pidHex,
          sample.parameter.label,
          sample.value,
          row.unit,
          sample.status.name,
          sample.requestedAt.toUtc().toIso8601String(),
          sample.receivedAt.toUtc().toIso8601String(),
          sample.latencyMs,
          sample.source,
        ].map(csvCell).join(','),
      );
    }
    await write(buffer.toString());
    cursor = page.last.id;
  }
}
