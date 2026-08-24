class HealthEvent {
  final DateTime date;
  final int score;
  final String description;
  final String? anomalyId;

  const HealthEvent({
    required this.date,
    required this.score,
    required this.description,
    this.anomalyId,
  });
}
