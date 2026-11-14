import 'package:flutter/foundation.dart';
import 'package:autopulse_ai/models/obd_dtc.dart';
import 'package:autopulse_ai/services/obd/dtc_parser.dart';
import 'package:autopulse_ai/services/obd/elm327_client.dart';
import 'package:autopulse_ai/services/obd/obd_parser.dart';

class DtcSnapshot {
  const DtcSnapshot({this.codes = const [], this.readAt, this.error});
  final List<ObdDtc> codes;
  final DateTime? readAt;
  final String? error;
}

/// Shares the ELM command queue with telemetry. No background Bluetooth service.
class DtcMonitor extends ChangeNotifier {
  DtcMonitor({
    required this.client,
    required this.isReady,
    required this.ecuSource,
  });
  final Elm327Client client;
  final bool Function() isReady;
  final String? Function() ecuSource;
  final Map<DtcKind, DtcSnapshot> _snapshots = {};
  final Set<String> _seen = {};
  bool scanning = false;
  bool? milOn;
  int? storedCount;
  String? milError;
  DateTime? milReadAt;
  DateTime? lastAttempt;
  List<String> alertCodes = const [];
  int alertRevision = 0;
  int _generation = 0;
  bool _disposed = false;

  DtcSnapshot snapshot(DtcKind kind) => _snapshots[kind] ?? const DtcSnapshot();
  bool get due =>
      !scanning &&
      (lastAttempt == null ||
          DateTime.now().difference(lastAttempt!) >=
              const Duration(seconds: 60));
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void reset() {
    _generation++;
    scanning = false;
    _snapshots.clear();
    _seen.clear();
    milOn = null;
    storedCount = null;
    milError = null;
    milReadAt = null;
    lastAttempt = null;
    alertCodes = const [];
    _changed();
  }

  /// Cancel in-flight results on disconnect, retaining previous readings as stale.
  void disconnected() {
    _generation++;
    scanning = false;
    _changed();
  }

  Future<void> scan() async {
    if (scanning || !isReady() || _disposed) return;
    final generation = _generation;
    bool current() => !_disposed && generation == _generation && isReady();
    scanning = true;
    lastAttempt = DateTime.now();
    _changed();
    final newCodes = <String>{};
    try {
      try {
        final raw = await client.command('0101');
        if (!current()) return;
        final bytes = ObdParser.select(
          ObdParser.responses(raw, 1, 4),
          source: ecuSource(),
        ).bytes;
        milOn = bytes[0] & 0x80 != 0;
        storedCount = bytes[0] & 0x7F;
        milReadAt = DateTime.now();
        milError = null;
      } catch (_) {
        if (!current()) return;
        milError = 'Check-engine light status unavailable.';
      }
      for (final kind in DtcKind.values) {
        if (!current()) return;
        try {
          final raw = await client.command(kind.command);
          if (!current()) return;
          final now = DateTime.now();
          final codes = DtcParser.parse(raw, kind, now);
          _snapshots[kind] = DtcSnapshot(
            codes: List.unmodifiable(codes),
            readAt: now,
          );
          for (final code in codes) {
            if (_seen.add(code.identity)) newCodes.add(code.code);
          }
        } catch (_) {
          if (!current()) return;
          final previous = snapshot(kind);
          _snapshots[kind] = DtcSnapshot(
            codes: previous.codes,
            readAt: previous.readAt,
            error: 'Unavailable or incomplete response. Previous readings, if any, are retained.',
          );
        }
      }
    } finally {
      if (current()) {
        scanning = false;
        // Codes can alert again after successful scans establish their absence.
        // Failed categories retain their previous codes and cannot clear them.
        _seen.retainAll(
          _snapshots.values
              .expand((s) => s.codes)
              .map((c) => c.identity)
              .toSet(),
        );
        if (newCodes.isNotEmpty) {
          alertCodes = List.unmodifiable(newCodes);
          alertRevision++;
        }
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
