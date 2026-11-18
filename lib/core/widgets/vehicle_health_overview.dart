import 'package:autopulse_ai/models/driving_context.dart';
import 'package:autopulse_ai/services/account_data_service.dart';
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
    if (mounted) {
      setState(() => _summary = _service?.healthSummary(widget.vehicleId));
    }
  }

  String _label(String condition) {
    if (condition == 'all') return 'Context unavailable';
    final parts = condition.split(':');
    return [
      DrivingState.values.byName(parts.first).label,
      if (parts.contains('demand')) 'High demand',
      if (parts.contains('initial')) 'Early drive',
      if (parts.contains('later')) 'Later drive',
    ].join(' Â· ');
  }

  String _range(Map signal, String unit) =>
      '${(signal['low'] as num).toStringAsFixed(1)}â€“'
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
      final saved = summary['saved'] as int;
      final analyzed = summary['analyzed'] as int;
      if (saved == 0) {
        return ListenableBuilder(
          listenable: AccountDataService.instance,
          builder: (context, _) => Text(
            AccountDataService.instance.busy ? 'Restoring your saved drives…' : 'Save a drive to see this car’s sensor history. For a new baseline, keep the adapter connected when you start and stop the drive.',
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            version == 0 ? 'Recorded ranges' : 'Personal baseline ready',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            analyzed == saved
                ? '$saved saved drives'
                : 'Preparing $analyzed of $saved drives',
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
            for (final item in signals)
              Builder(
                builder: (context) {
                  final signal = item as Map;
                  final unit = signal['unit'] == 'C'
                      ? '°C'
                      : signal['unit'] as String? ?? '';
                  final band =
                      (signal['example_band'] ?? signal['expected']) as Map?;
                  final observed = signal['low'] == null
                      ? null
                      : _range(signal, unit);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(signal['name'] as String),
                    subtitle: Text(
                      band == null
                          ? observed ?? 'Range unavailable'
                          : 'Expected: ${_range(band, unit)}',
                    ),
                  );
                },
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('About these ranges'),
              children: [
                const ListTile(
                  title: Text(
                    'Recorded ranges combine the middle readings from comparable drives. Expected ranges come from your personal model once it is available.',
                  ),
                ),
                if (version > 0)
                  ListTile(
                    title: Text('$checked drives checked · Model v$version'),
                  ),
              ],
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
              'Automatic alerts are pending for this car. You can still review its recorded ranges.',
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
                title: Text('${finding['signal']} Â· ${finding['direction']}'),
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
