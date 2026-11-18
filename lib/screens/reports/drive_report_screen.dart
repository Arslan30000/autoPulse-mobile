import 'package:autopulse_ai/core/widgets/local_diagnostic_report.dart';
import 'package:flutter/material.dart';

class DriveReportScreen extends StatelessWidget {
  const DriveReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drive Report')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: LocalDiagnosticReport(),
        ),
      ),
    );
  }
}
