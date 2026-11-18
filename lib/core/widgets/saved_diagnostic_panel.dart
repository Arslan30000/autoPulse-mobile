import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/diagnostics/vehicle_diagnostics.dart';
import 'package:autopulse_ai/services/account_data_service.dart';
import 'package:flutter/material.dart';

import 'sensor_range_meter.dart';

class SavedDiagnosticPanel extends StatefulWidget {
  const SavedDiagnosticPanel({super.key, required this.sessionId});
  final int sessionId;

  @override
  State<SavedDiagnosticPanel> createState() => _SavedDiagnosticPanelState();
}

class _SavedDiagnosticPanelState extends State<SavedDiagnosticPanel> {
  final pipeline = VehicleDiagnostics.instance;
  Future<Map<String, dynamic>?>? _result;

  @override
  void initState() {
    super.initState();
    pipeline?.addListener(_changed);
    _result = pipeline?.result(widget.sessionId);
    pipeline?.evaluate(widget.sessionId);
  }

  void _changed() {
    if (mounted) setState(() => _result = pipeline?.result(widget.sessionId));
  }

  @override
  void dispose() {
    pipeline?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _result,
    builder: (context, snapshot) {
      final report = snapshot.connectionState == ConnectionState.done
          ? snapshot.data
          : null;
      if (report == null) {
        return ListTile(
          leading: const Icon(Icons.monitor_heart_outlined),
          title: const Text('Recording diagnostics'),
          subtitle: Text(
            snapshot.hasError || pipeline?.error != null
                ? 'Analysis unavailable. Tap to retry.'
                : pipeline == null
                ? 'Available on mobile.'
                : 'Waiting for analysis.',
          ),
          onTap: pipeline == null
              ? null
              : () => pipeline!.evaluate(widget.sessionId),
        );
      }
      return DiagnosticResultView(report: report);
    },
  );
}

class DiagnosticResultView extends StatelessWidget {
  const DiagnosticResultView({super.key, required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final checks = (report['checks'] as Map).entries;
    final codes = report['dtc_evidence'] as List;
    final events = report['events'] as List;
    final gate = report['dtc_gate'] as String;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report['reference'] == true
              ? 'Personal reference updated · v${report['reference_version']}'
              : report['model_version'] == 0
              ? 'Recorded sensor ranges'
              : '${report['status']} · Personal reference v${report['model_version']}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(switch (gate) {
          'fault' => 'The ECU reported a fault indication. This drive is excluded from baseline learning.',
          'clean' => 'Opening and closing ECU scans completed without fault indications.',
          _ => 'Start and stop a drive with the adapter connected to qualify a personal model baseline.',
        }),
        const SizedBox(height: 8),
        const Text(
          'Choose a driving condition to see its range. Observed bands show the middle 80% of recorded values.',
        ),
        const SizedBox(height: 12),
        if (codes.isNotEmpty)
          Text(
            'ECU codes: ${codes.map((code) => "${code['code']} (${code['status']})").join(', ')}',
          ),
        for (final entry in checks)
          SensorRangeMeter(
            key: ValueKey(entry.key),
            check: entry.value as Map,
            previous:
                (report['previous_ranges'] as Map?)?[entry.key] as Map? ?? {},
            findings: events
                .where((event) => '${event['pid']}' == entry.key)
                .length,
          ),
        for (final event in events)
          ExpansionTile(
            title: Text('${event['signal']} · ${event['direction']}'),
            subtitle: Text('${event['context']} · ${event['detected_at']}'),
            children: [
              ListTile(
                subtitle: Text(
                  'Observed ${event['observed']} ${event['unit']}, expected '
                  '${event['expected']} ${event['unit']}, threshold '
                  '${event['threshold']} ${event['unit']}.\n${event['suggested_check']}',
                ),
              ),
              for (final code in event['related_session_codes'] as List)
                ListTile(
                  title: Text('${code['code']} · ${code['status']}'),
                  subtitle: Text('Scan: ${code['scan_time']}'),
                ),
            ],
          ),
      ],
    );
  }
}

/// Uses the same account-scoped recording store as the recording history.
class DiagnosticRecordingList extends StatefulWidget {
  const DiagnosticRecordingList({
    super.key,
    this.vehicleId,
    this.latestOnly = false,
    this.onSelected,
  });
  final String? vehicleId;
  final bool latestOnly;
  final void Function(ObdRecording)? onSelected;

  @override
  State<DiagnosticRecordingList> createState() =>
      _DiagnosticRecordingListState();
}

class _DiagnosticRecordingListState extends State<DiagnosticRecordingList> {
  final pipeline = VehicleDiagnostics.instance;
  Future<List<ObdRecording>>? _runs;

  @override
  void initState() {
    super.initState();
    pipeline?.addListener(_change);
    _runs = _read();
  }

  @override
  void didUpdateWidget(DiagnosticRecordingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicleId != widget.vehicleId) _runs = _read();
  }

  @override
  void dispose() {
    pipeline?.removeListener(_change);
    super.dispose();
  }

  void _change() {
    if (mounted) setState(() => _runs = _read());
  }

  Future<List<ObdRecording>> _read() async {
    final service = pipeline;
    if (service == null) return [];
    final runs = <ObdRecording>[];
    var cursor = 0;
    while (true) {
      final page = await service.visibleRecordings(cursor);
      if (page.isEmpty) return runs;
      for (final run in page) {
        if (run.endedAt == null ||
            (widget.vehicleId != null && run.vehicle?.id != widget.vehicleId)) {
          continue;
        }
        runs.add(run);
        if (widget.latestOnly) return runs;
      }
      cursor = page.last.id;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ObdRecording>>(
    future: _runs,
    builder: (context, snapshot) {
      final runs = snapshot.connectionState == ConnectionState.done
          ? snapshot.data ?? <ObdRecording>[]
          : <ObdRecording>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pipeline?.running == true)
            const LinearProgressIndicator(
              semanticsLabel: 'Checking saved recordings',
            ),
          if (pipeline?.error case final error?) Text(error),
          if (snapshot.hasError)
            const Text('Saved recordings could not be read.'),
          if (pipeline != null && !widget.latestOnly)
            OutlinedButton.icon(
              onPressed: pipeline!.running ? null : pipeline!.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Check saved recordings'),
            ),
          if (runs.isEmpty && !snapshot.hasError)
            ListenableBuilder(
              listenable: AccountDataService.instance,
              builder: (context, _) {
                final account = AccountDataService.instance;
                if (pipeline != null && account.busy) {
                  return const Text(
                    'Restoring saved drives. Sensor ranges appear as drives finish restoring.',
                  );
                }
                return Text(
                  pipeline == null
                      ? 'Recording diagnostics are available on mobile.'
                      : 'No completed recordings for this car yet.',
                );
              },
            ),
          for (final run in runs)
            if (widget.latestOnly)
              SavedDiagnosticPanel(key: ValueKey(run.id), sessionId: run.id)
            else
              ListTile(
                title: Text(run.vehicleName),
                subtitle: Text(
                  run.startedAt.toLocal().toString().split('.').first,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onSelected?.call(run),
              ),
        ],
      );
    },
  );
}
