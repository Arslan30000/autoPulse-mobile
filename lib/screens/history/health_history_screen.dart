import 'package:autopulse_ai/core/widgets/local_diagnostic_report.dart';
import 'package:flutter/material.dart';

class HealthHistoryScreen extends StatelessWidget {
  const HealthHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic History')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LocalDiagnosticReport(
              history: true,
              initialReport: arguments is Map<String, dynamic>
                  ? arguments
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
