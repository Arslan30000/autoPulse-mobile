import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/widgets/live_obd_view.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

/// Both roles share one real connection and polling scheduler.
class LiveMonitorScreen extends StatelessWidget {
  final ObdController? controller;

  const LiveMonitorScreen({super.key, this.controller});

  @override
  Widget build(BuildContext context) => LiveObdView(
    title: 'Live Monitor',
    controller: controller ?? ObdController.instance,
  );
}
