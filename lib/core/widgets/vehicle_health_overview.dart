import 'package:autopulse_ai/models/driving_context.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/diagnostics/vehicle_diagnostics.dart';
import 'package:flutter/material.dart';

class VehicleHealthOverview extends StatefulWidget {
  const VehicleHealthOverview({super.key, required this.vehicleId});
  final String? vehicleId;

  @override
  State<VehicleHealthOverview> createState() => _VehicleHealthOverviewState();
}

class _VehicleHealthOverviewState extends State<VehicleHealthOverview> {
  final _service = VehicleDiagnostics.instance;
  Future<Map<String, dynamic>?>? _summary;
  String? _condition;

  @override
  void initState() {
    super.initState();
    _summary = _service?.healthSummary(widget.vehicleId);
    _service?.addListener(_reload);
  }

  @override
  void didUpdateWidget(VehicleHealthOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicleId != widget.vehicleId) {
      _condition = null;
      _summary = _service?.healthSummary(widget.vehicleId);
    }
  }

  @override
  void dispose() {
    _service?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted)
      setState(() => _summary = _service?.healthSummary(widget.vehicleId));
  }

  String _label(String condition) {
    if (condition == 'all') return 'Context unavailable';
    final parts = condition.split(':');
    return [
      DrivingState.values.byName(parts.first).label,
      if (parts.contains('demand')) 'High demand',
      if (parts.contains('initial')) 'First 10 min',
      if (parts.contains('later')) 'Later in drive',
    ].join(' · ');
  }

  String _range(Map signal, String unit) =>
      '${(signal['low'] as num).toStringAsFixed(1)}–'
      '${(signal['high'] as num).toStringAsFixed(1)} $unit';

  Future<void> _openFinding(int id) async {
    final run = await _service?.visibleRecording(id);
    if (!mounted || run == null) return;
    await Navigator.pushNamed(context, AppRouter.driveReport, arguments: run);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _summary,
    builder: (context, snapshot) {
      final theme = Theme.of(context);
      if (snapshot.hasError) {
        return TextButton(
          onPressed: _reload,
          child: const Text('Retry loading vehicle baseline'),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LinearProgressIndicator(
          semanticsLabel: 'Loading vehicle baseline',
        );
      }
      final summary = snapshot.data;
      if (summary == null) {
        return const Text(
          'Select a car and save or restore a drive to see its sensor ranges.',
        );
      }
      final contexts = summary['contexts'] as Map;
      final options = contexts.keys.cast<String>().toList()
        ..sort(
          (a, b) => a == 'all'
              ? 1
              : b == 'all'
              ? -1
              : a.compareTo(b),
        );
      final selected = options.contains(_condition)
          ? _condition
          : options.firstOrNull;
      final signals = (contexts[selected] as Map?)?.values ?? const [];
      final version = summary['reference_version'] as int;
      final checked = summary['checked'] as int;
      final findings = summary['findings'] as List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            version == 0
                ? 'Learning personal baseline'
                : 'Personal baseline v$version',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${summary['analyzed']} of ${summary['saved']} saved drives analyzed'
            ' · $checked checked against a model',
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            DropdownButton<String>(
              isExpanded: true,
              value: selected,
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option,
                    child: Text(
                      _label(option),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _condition = value),
            ),
            const Text(
              'Historical bands span the middle 80% ranges of the contributing drives. Model ranges show an example for this condition.',
            ),
            const SizedBox(height: 6),
            for (final item in signals)
              Builder(
                builder: (context) {
                  final signal = item as Map;
                  final unit = signal['unit'] == 'C'
                      ? '°C'
                      : signal['unit'] as String? ?? '';
                  final expected = signal['expected'] as Map?;
                  final example = signal['example_band'] as Map?;
                  return Card(
                    child: ListTile(
                      title: Text(signal['name'] as String),
                      subtitle: Text(
                        [
                          if (signal['low'] != null)
                            'Historical: ${_range(signal, unit)} · ${signal['drives']} drives',
                          if (example != null)
                            'Model example: ${_range(example, unit)}'
                          else if (expected != null)
                            'Latest expected: ${_range(expected, unit)}',
                          if (example == null &&
                              expected == null &&
                              version > 0)
                            'Awaiting a comparison with the current model',
                        ].join('\n'),
                      ),
                    ),
                  );
                },
              ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Ranges appear after a saved drive is analyzed.'),
            ),
          const SizedBox(height: 20),
          Text('Recent anomalies', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          if (version == 0)
            const Text(
              'Anomaly detection is waiting for a qualified baseline. Start and stop a drive with the adapter connected so both ECU scans can finish.',
            )
          else if (checked == 0)
            const Text(
              'The baseline is ready. No saved drive has been scored against a model yet.',
            )
          else if (findings.isEmpty)
            const Text('No sustained anomalies found in the checked drives.')
          else ...[
            if ((summary['finding_count'] as int) > findings.length)
              Text(
                'Showing the latest ${findings.length} of ${summary['finding_count']} findings.',
              ),
            for (final finding in findings)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.tertiary,
                ),
                title: Text('${finding['signal']} · ${finding['direction']}'),
                subtitle: Text(
                  '${_label(finding['context'] as String)}\n'
                  '${DateTime.parse(finding['detected_at'] as String).toLocal().toString().split('.').first}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openFinding(finding['recording_id'] as int),
              ),
          ],
        ],
      );
    },
  );
}
