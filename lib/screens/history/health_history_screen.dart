import 'package:autopulse_ai/core/widgets/saved_diagnostic_panel.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:flutter/material.dart';

class HealthHistoryScreen extends StatelessWidget {
  const HealthHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Diagnostic History')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DiagnosticRecordingList(
            onSelected: (run) => Navigator.pushNamed(
              context,
              AppRouter.driveReport,
              arguments: run,
            ),
          ),
        ],
      ),
    ),
  );
}
