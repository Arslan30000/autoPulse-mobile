import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/connection_sheet.dart';
import 'package:autopulse_ai/models/obd_dtc.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, this.controller});
  final ObdController? controller;
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  DtcKind _selected = DtcKind.stored;
  ObdController get controller => widget.controller ?? ObdController.instance;

  String _time(DateTime? value) => value == null
      ? 'Not read yet'
      : value.toLocal().toString().split('.').first;

  Widget _panel(Widget child, {Color color = AppColors.border}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.diagnostics]),
    builder: (context, _) {
      final monitor = controller.diagnostics;
      final snapshot = monitor.snapshot(_selected);
      final fresh =
          controller.isReady &&
          snapshot.error == null &&
          snapshot.readAt != null;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Diagnostic codes')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                controller.vehicle.fullDisplayName,
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Read codes directly from your vehicle ECU.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 20),
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.engineering_outlined,
                          color: monitor.milOn == true
                              ? AppColors.warning
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Check-engine light',
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      monitor.milOn == null
                          ? 'Status not available'
                          : 'ECU reported: ${monitor.milOn! ? 'ON' : 'OFF'}',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: monitor.milOn == true
                            ? AppColors.warning
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last read: ${_time(monitor.milReadAt)}',
                      style: AppTextStyles.bodySmall,
                    ),
                    if (monitor.storedCount != null)
                      Text(
                        'ECU-reported stored count: ${monitor.storedCount}',
                        style: AppTextStyles.bodySmall,
                      ),
                    if (monitor.milError != null)
                      Text(
                        monitor.milError!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    if (!controller.isReady && monitor.milReadAt != null)
                      const Text(
                        'Previous connection • status may have changed.',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!controller.isReady) ...[
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connect to scan', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Pair your ELM327, switch the ignition on, then connect. Previous scan results remain visible until reconnecting.',
                      ),
                      if (controller.error != null) Text(controller.error!),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => showConnectionSheet(
                          context,
                          controller: controller,
                        ),
                        icon: const Icon(Icons.bluetooth),
                        label: const Text('Connect adapter'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: controller.isReady && !monitor.scanning
                    ? monitor.scan
                    : null,
                icon: monitor.scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  monitor.scanning ? 'Reading ECU…' : 'Scan diagnostic codes',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Automatic checks every 60 seconds while connected and the app is open.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in DtcKind.values)
                    ChoiceChip(
                      label: Text(
                        '${kind.label} ${monitor.snapshot(kind).readAt == null ? '—' : monitor.snapshot(kind).codes.length}',
                      ),
                      selected: kind == _selected,
                      onSelected: (_) => setState(() => _selected = kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(_selected.explanation, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 8),
              Text(
                'Last successful read: ${_time(snapshot.readAt)}',
                style: AppTextStyles.bodySmall,
              ),
              if (snapshot.error != null) ...[
                const SizedBox(height: 12),
                _panel(
                  Text(
                    snapshot.error!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                  color: AppColors.warning,
                ),
              ],
              const SizedBox(height: 12),
              if (snapshot.codes.isEmpty)
                _panel(
                  Column(
                    children: [
                      Icon(
                        snapshot.readAt == null
                            ? Icons.search
                            : Icons.fact_check_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.readAt == null
                            ? 'No scan results yet'
                            : fresh
                            ? 'No ${_selected.label.toLowerCase()} codes reported'
                            : 'No codes in the previous successful scan',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'An empty code list does not establish overall vehicle health.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              for (final code in snapshot.codes) ...[
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SelectableText(
                            code.code,
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                          Chip(label: Text(code.kind.label)),
                          if (!fresh)
                            const Text(
                              'Previous reading',
                              style: TextStyle(color: AppColors.warning),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(code.description, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 12),
                      Text(
                        'ECU: ${code.source} • Read: ${_time(code.readAt)}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Text(
                'Standard OBD emissions diagnostics. Manufacturer-specific systems may require a dedicated scanner. Codes identify detected conditions, not a confirmed failed part.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    },
  );
}
