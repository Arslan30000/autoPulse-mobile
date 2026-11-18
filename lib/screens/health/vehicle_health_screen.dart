import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/widgets/driving_context_card.dart';
import 'package:autopulse_ai/core/widgets/local_diagnostic_report.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:flutter/material.dart';

class VehicleHealthScreen extends StatelessWidget {
  const VehicleHealthScreen({super.key, this.contextController});

  final DrivingContextController? contextController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vehicle Health')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DrivingContextCard(
                    controller:
                        contextController ??
                        ObdController.instance.drivingContext,
                  ),
                  const SizedBox(height: 24),
                  const LocalDiagnosticReport(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
