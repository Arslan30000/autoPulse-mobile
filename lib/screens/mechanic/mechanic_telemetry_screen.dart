import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/widgets/live_obd_view.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

/// Both roles share one real connection and polling scheduler.
class MechanicTelemetryScreen extends StatelessWidget {
  final ObdController? controller;
  const MechanicTelemetryScreen({super.key, this.controller});
  @override
  Widget build(BuildContext context) => LiveObdView(
    title: 'Telemetry',
    controller: controller ?? ObdController.instance,
  );
}
