class Anomaly {
  final String id;
  final String title;
  final String severity;
  final String status;
  final String description;
  final String detailedDescription;
  final DateTime detectedAt;
  final List<String> contributingFactors;
  final List<String> recommendedChecks;
  final Map<String, String> supportingTelemetry;

  const Anomaly({
    required this.id,
    required this.title,
    required this.severity,
    required this.status,
    required this.description,
    required this.detailedDescription,
    required this.detectedAt,
    required this.contributingFactors,
    required this.recommendedChecks,
    required this.supportingTelemetry,
  });
}

class DTC {
  final String code;
  final String description;
  final String status;

  const DTC({
    required this.code,
    required this.description,
    required this.status,
  });
}
