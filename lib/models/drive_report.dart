class DriveReport {
  final double distance;
  final double avgSpeed;
  final int anomalyCount;
  final int dtcCount;
  final int healthScore;
  final String summary;
  final Map<String, String> systemStatuses;
  final DateTime date;

  const DriveReport({
    required this.distance,
    required this.avgSpeed,
    required this.anomalyCount,
    required this.dtcCount,
    required this.healthScore,
    required this.summary,
    required this.systemStatuses,
    required this.date,
  });
}
