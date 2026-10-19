import 'package:flutter/material.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';
import 'package:autopulse_ai/screens/history/recordings_screen.dart';
import 'package:autopulse_ai/core/widgets/obd_telemetry_chart.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/widgets/obd_connection_panel.dart';
import 'package:autopulse_ai/core/widgets/telemetry_card.dart';
import 'package:autopulse_ai/core/widgets/telemetry_gauge.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

class LiveObdView extends StatelessWidget {
  final String title;
  final ObdController controller;
  const LiveObdView({super.key, required this.title, required this.controller});
  Future<void> _recordings(BuildContext context) async {
    final repository = controller.repository;
    if (repository is! RecordingStore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording inspection is unavailable.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordingsScreen(
          store: repository,
          sync: RecordingSyncService.instance,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final obd = controller;
    const gaugeParameters = [
      ObdParameter.rpm,
      ObdParameter.speed,
      ObdParameter.coolant,
    ];
    final otherParameters = ObdParameter.values
        .where((p) => !gaugeParameters.contains(p))
        .toList();
    return ListenableBuilder(
      listenable: obd,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              tooltip: 'Local recordings',
              onPressed: !obd.transport.isSupported
                  ? null
                  : () => _recordings(context),
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obd.vehicle.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ObdConnectionPanel(controller: obd),
                ),
                const Divider(height: 32),
                if (obd.isReady)
                  Text(
                    'ECU ${obd.ecuSource}  |  ${obd.supported.length} supported parameters',
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 24),
                        child: Text(
                          'At a glance',
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (final p in gaugeParameters)
                            Expanded(
                              flex: p == ObdParameter.speed ? 5 : 4,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: TelemetryGauge(
                                  label: p == ObdParameter.rpm
                                      ? 'Engine RPM'
                                      : p == ObdParameter.speed
                                      ? 'Speed'
                                      : 'Coolant',
                                  unit: p == ObdParameter.coolant
                                      ? '°C'
                                      : p.unit,
                                  value: _valid(p)
                                      ? obd.samples[p]!.value
                                      : null,
                                  quality: _quality(p),
                                  minimum: p == ObdParameter.coolant ? -40 : 0,
                                  maximum: p == ObdParameter.rpm
                                      ? 8000
                                      : p == ObdParameter.speed
                                      ? 240
                                      : 160,
                                  divisions: p == ObdParameter.rpm
                                      ? 8
                                      : p == ObdParameter.speed
                                      ? 6
                                      : 5,
                                  tickDivisor: p == ObdParameter.rpm ? 1000 : 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('More parameters', style: AppTextStyles.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Readings reported by your vehicle’s ECU.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 800
                        ? 4
                        : constraints.maxWidth >= 550
                        ? 3
                        : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: otherParameters.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 155,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final p = otherParameters[index];
                        final sample = obd.samples[p];
                        final valid = _valid(p);
                        final quality = _quality(p);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TelemetryCard(
                                label: p.label,
                                value: valid
                                    ? sample!.value!.toStringAsFixed(p.decimals)
                                    : '--',
                                unit: p.unit,
                                icon: _icon(p),
                                statusColor: valid
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                quality,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'RPM history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ObdTelemetryChart(
                  samples: obd.rpmHistory,
                  parameter: ObdParameter.rpm,
                  live: true,
                ),
                const Divider(height: 32),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: obd.recordingBusy || !obd.isReady
                          ? null
                          : obd.isRecording
                          ? obd.stopRecording
                          : obd.startRecording,
                      icon: Icon(
                        obd.isRecording
                            ? Icons.stop
                            : Icons.fiber_manual_record,
                      ),
                      label: Text(
                        obd.isRecording ? 'Stop recording' : 'Record drive',
                      ),
                    ),
                    if (obd.isRecording || obd.savedSamples > 0)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '${obd.savedSamples} samples saved locally',
                        ),
                      ),
                  ],
                ),
                if (obd.storageError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      obd.storageError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _icon(ObdParameter p) => switch (p) {
    ObdParameter.rpm => Icons.speed,
    ObdParameter.speed => Icons.directions_car,
    ObdParameter.coolant || ObdParameter.intake => Icons.thermostat,
    ObdParameter.maf || ObdParameter.map => Icons.air,
    _ => Icons.settings_input_component,
  };

  bool _stale(ObdSample sample) =>
      DateTime.now().difference(sample.receivedAt) > const Duration(seconds: 6);
  bool _valid(ObdParameter p) {
    final sample = controller.samples[p];
    return controller.isReady &&
        controller.supported.contains(p) &&
        sample != null &&
        sample.status == ObdSampleStatus.valid &&
        sample.value != null &&
        sample.value!.isFinite &&
        !_stale(sample);
  }

  String _quality(ObdParameter p) {
    final sample = controller.samples[p];
    if (!controller.isReady) return 'Disconnected';
    if (!controller.supported.contains(p)) return 'Not supported';
    if (sample == null) return 'Waiting';
    if (_stale(sample)) return 'Stale';
    if (_valid(p)) return '${sample.latencyMs} ms response';
    return switch (sample.status) {
      ObdSampleStatus.unsupported => 'Not supported',
      ObdSampleStatus.noData => 'No data',
      ObdSampleStatus.timeout => 'Timed out',
      _ => 'Invalid response',
    };
  }
}
