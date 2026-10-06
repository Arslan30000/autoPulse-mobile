import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

class ObdConnectionPanel extends StatelessWidget {
  final ObdController controller;
  const ObdConnectionPanel({super.key, required this.controller});
  Future<void> _chooseDevice(BuildContext context) async {
    await controller.loadDevices();
    if (!context.mounted || controller.error != null) return;
    final selected = await showModalBottomSheet<ObdDevice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Paired adapters',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            if (controller.devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No paired Bluetooth Classic devices'),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: controller.devices
                    .map(
                      (device) => ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name),
                        subtitle: Text(device.address),
                        onTap: () => Navigator.pop(context, device),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && context.mounted) await controller.connect(selected);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final status = switch (controller.status) {
        ObdConnectionStatus.disconnected => 'Disconnected',
        ObdConnectionStatus.connecting => 'Connecting to adapter',
        ObdConnectionStatus.initializing => 'Detecting vehicle ECU',
        ObdConnectionStatus.ready => 'Vehicle connected',
        ObdConnectionStatus.error => 'Connection failed',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bluetooth,
                color: controller.isReady
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (controller.isBusy || controller.loadingDevices)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (controller.device != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(controller.device!.name),
            ),
          if (!controller.transport.isSupported)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Bluetooth Classic is available on Android only.'),
            ),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                controller.error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed:
                    !controller.transport.isSupported ||
                        controller.isBusy ||
                        controller.loadingDevices ||
                        controller.isReady
                    ? null
                    : () => _chooseDevice(context),
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(
                  controller.status == ObdConnectionStatus.error
                      ? 'Reconnect'
                      : 'Connect adapter',
                ),
              ),
              if (controller.isReady || controller.isBusy)
                OutlinedButton.icon(
                  onPressed: controller.disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
              if (controller.transport.isSupported &&
                  !controller.isReady &&
                  !controller.isBusy)
                OutlinedButton.icon(
                  onPressed: controller.openSettings,
                  icon: const Icon(Icons.settings_bluetooth),
                  label: const Text('Bluetooth settings'),
                ),
            ],
          ),
        ],
      );
    },
  );
}
