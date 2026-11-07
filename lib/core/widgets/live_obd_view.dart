import 'package:flutter/material.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';
import 'package:autopulse_ai/screens/history/recordings_screen.dart';
import 'package:autopulse_ai/core/widgets/obd_telemetry_chart.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          obd.vehicle.displayName,
                          style: AppTextStyles.titleMedium,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (obd.isReady
                                        ? AppColors.success
                                        : AppColors.textTertiary)
                                    .withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            obd.isReady ? 'LIVE' : 'OFFLINE',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: obd.isReady
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 700) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _gaugeCard(ObdParameter.rpm)),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 2,
                                child: _gaugeCard(
                                  ObdParameter.speed,
                                  featured: true,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: _gaugeCard(ObdParameter.coolant)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _gaugeCard(ObdParameter.speed, featured: true),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _gaugeCard(ObdParameter.rpm)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _gaugeCard(ObdParameter.coolant),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: obd.recordingBusy || !obd.isReady
                              ? null
                              : obd.isRecording
                              ? obd.stopRecording
                              : obd.startRecording,
                          icon: Icon(
                            obd.isRecording
                                ? Icons.stop_rounded
                                : Icons.fiber_manual_record,
                            size: 18,
                          ),
                          label: Text(
                            obd.isRecording ? 'Stop recording' : 'Record drive',
                          ),
                        ),
                        if (obd.isRecording || obd.savedSamples > 0)
                          Text(
                            '${obd.savedSamples} samples saved',
                            style: AppTextStyles.bodySmall,
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
                    const SizedBox(height: 28),
                    Text('Engine data', style: AppTextStyles.titleLarge),
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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
                                        ? sample!.value!.toStringAsFixed(
                                            p.decimals,
                                          )
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gaugeCard(ObdParameter p, {bool featured = false}) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      featured ? 20 : 10,
      16,
      featured ? 20 : 10,
      14,
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: featured
            ? const [Color(0xFF193B49), Color(0xFF0D202B)]
            : const [Color(0xFF172E3A), Color(0xFF112630)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(featured ? 28 : 22),
      border: Border.all(
        color: featured
            ? AppColors.primary.withValues(alpha: .32)
            : AppColors.border,
      ),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: featured ? 270 : 210),
        child: TelemetryGauge(
          label: p == ObdParameter.rpm
              ? 'Engine RPM'
              : p == ObdParameter.speed
              ? 'Speed'
              : 'Coolant',
          unit: p == ObdParameter.coolant ? '\u00b0C' : p.unit,
          value: _valid(p) ? controller.samples[p]!.value : null,
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
          accentColor: p == ObdParameter.coolant
              ? const Color(0xFFFFC16B)
              : AppColors.primary,
        ),
      ),
    ),
  );

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
