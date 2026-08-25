enum SystemStatus { normal, attention, warning, critical }

class SystemHealth {
  final String name;
  final SystemStatus status;
  final String? description;
  final String icon;

  const SystemHealth({
    required this.name,
    required this.status,
    this.description,
    required this.icon,
  });

  String get statusLabel {
    switch (status) {
      case SystemStatus.normal:
        return 'Normal';
      case SystemStatus.attention:
        return 'Attention';
      case SystemStatus.warning:
        return 'Warning';
      case SystemStatus.critical:
        return 'Critical';
    }
  }
}

class VehicleHealth {
  final int score;
  final String status;
  final List<SystemHealth> systems;

  const VehicleHealth({
    required this.score,
    required this.status,
    required this.systems,
  });
}