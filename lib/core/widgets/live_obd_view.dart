import 'package:flutter/material.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';
import 'package:autopulse_ai/screens/history/recordings_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/widgets/obd_connection_panel.dart';
import 'package:autopulse_ai/core/widgets/telemetry_card.dart';
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
                ObdConnectionPanel(controller: obd),
                const Divider(height: 32),
                if (obd.isReady)
                  Text(
                    'ECU ${obd.ecuSource}  |  ${obd.supported.length} supported parameters',
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
                      itemCount: ObdParameter.values.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 155,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final p = ObdParameter.values[index];
                        final sample = obd.samples[p];
                        final stale =
                            sample != null &&
                            DateTime.now().difference(sample.receivedAt) >
                                const Duration(seconds: 6);
                        final valid =
                            obd.isReady &&
                            sample?.status == ObdSampleStatus.valid &&
                            !stale;
                        final quality = !obd.isReady
                            ? 'Disconnected'
                            : !obd.supported.contains(p)
                            ? 'Not supported'
                            : sample == null
                            ? 'Waiting'
                            : stale
                            ? 'Stale'
                            : sample.status == ObdSampleStatus.valid
                            ? '${sample.latencyMs} ms response'
                            : sample.status == ObdSampleStatus.noData
                            ? 'No data'
                            : 'Invalid response';
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
                SizedBox(
                  height: 180,
                  child: obd.rpmHistory.length < 2
                      ? const Center(child: Text('Waiting for RPM samples'))
                      : _chart(obd),
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

  Widget _chart(ObdController obd) {
    final samples = obd.rpmHistory;
    final start = samples.first.receivedAt;
    return LineChart(
      LineChartData(
        minY: 0,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: samples
                .map(
                  (s) => FlSpot(
                    s.receivedAt.difference(start).inMilliseconds / 1000,
                    s.value!,
                  ),
                )
                .toList(),
            color: AppColors.primary,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: false),
          ),
        ],
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
}
