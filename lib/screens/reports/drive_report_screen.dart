import 'package:autopulse_ai/core/widgets/saved_diagnostic_panel.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:flutter/material.dart';

class DriveReportScreen extends StatelessWidget {
  const DriveReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recording = ModalRoute.of(context)?.settings.arguments;
    final run = recording is ObdRecording ? recording : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Drive Report')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (run == null)
              const DiagnosticRecordingList(latestOnly: true)
            else ...[
              Text(
                run.vehicleName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SavedDiagnosticPanel(sessionId: run.id),
            ],
          ],
        ),
      ),
    );
  }
}
