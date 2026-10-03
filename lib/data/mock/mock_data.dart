import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/models/telemetry.dart';
import 'package:autopulse_ai/models/health.dart';
import 'package:autopulse_ai/models/diagnostic.dart';
import 'package:autopulse_ai/models/ai_message.dart';
import 'package:autopulse_ai/models/drive_report.dart';
import 'package:autopulse_ai/models/health_event.dart';

class MockData {
  MockData._();

  static const vehicle = Vehicle(
    make: 'Toyota',
    model: 'Yaris',
    year: 2020,
    isConnected: true,
  );

  static final currentTelemetry = TelemetryData(
    rpm: 780,
    speed: 0,
    coolantTemperature: 69,
    intakeTemperature: 63,
    engineLoad: 12,
    throttlePosition: 18.04,
    maf: 0.21,
    timestamp: DateTime(2025, 8, 24, 12, 28),
  );

  static const vehicleHealth = VehicleHealth(
    score: 87,
    status: 'Good',
    systems: [
      SystemHealth(name: 'Engine', status: SystemStatus.normal, icon: 'engine'),
      SystemHealth(name: 'Cooling', status: SystemStatus.normal, icon: 'cooling'),
      SystemHealth(
        name: 'Air Intake',
        status: SystemStatus.attention,
        description: 'Airflow-related telemetry has deviated from the vehicle\'s learned baseline.',
        icon: 'air_intake',
      ),
      SystemHealth(name: 'Sensors', status: SystemStatus.normal, icon: 'sensors'),
      SystemHealth(name: 'Electrical', status: SystemStatus.normal, icon: 'electrical'),
      SystemHealth(name: 'Transmission', status: SystemStatus.normal, icon: 'transmission'),
    ],
  );

  static final anomalies = [
    Anomaly(
      id: 'air_intake_001',
      title: 'Air Intake Behavior',
      severity: 'Moderate',
      status: 'Needs Attention',
      description: 'Telemetry differs from the vehicle\'s normal operating pattern.',
      detailedDescription:
          'Airflow-related telemetry differs from the vehicle\'s historical operating pattern.',
      detectedAt: DateTime(2025, 8, 24, 12, 28),
      contributingFactors: [
        'Airflow sensor behavior',
        'Intake restriction',
        'Sensor-related irregularity',
      ],
      recommendedChecks: [
        'Inspect the air intake system.',
        'Check the MAF sensor and connections.',
        'Monitor whether the anomaly repeats.',
        'Consult a qualified mechanic if the issue persists.',
      ],
      supportingTelemetry: {
        'MAF': '0.21 g/s',
        'Engine Load': '12 %',
        'Throttle': '18.04 %',
      },
    ),
  ];

  static const dtcs = [
    DTC(
      code: 'P0101',
      description: 'Mass or Volume Air Flow Circuit Range/Performance',
      status: 'Needs Investigation',
    ),
  ];

  static final healthHistory = [
    HealthEvent(
      date: DateTime(2025, 8, 24),
      score: 87,
      description: 'Air Intake anomaly detected',
      anomalyId: 'air_intake_001',
    ),
    HealthEvent(
      date: DateTime(2025, 8, 20),
      score: 91,
      description: 'No major anomalies',
    ),
    HealthEvent(
      date: DateTime(2025, 8, 17),
      score: 94,
      description: 'Normal operation',
    ),
    HealthEvent(
      date: DateTime(2025, 8, 12),
      score: 93,
      description: 'Normal operation',
    ),
  ];

  static final driveReport = DriveReport(
    distance: 24.6,
    avgSpeed: 38,
    anomalyCount: 1,
    dtcCount: 1,
    healthScore: 87,
    summary:
        'Vehicle operated normally for most of the drive. One moderate airflow-related anomaly was detected.',
    systemStatuses: {
      'Engine': 'Normal',
      'Cooling': 'Normal',
      'Air Intake': 'Attention',
      'Sensors': 'Normal',
    },
    date: DateTime(2025, 8, 24),
  );

  static final aiConversation = [
    AIMessage(
      content: 'Why did I get this warning?',
      isUser: true,
      timestamp: DateTime(2025, 8, 24, 12, 30),
    ),
    AIMessage(
      content:
          'An airflow-related anomaly was detected because the vehicle\'s current telemetry differs from its learned operating pattern under similar conditions.\n\nPossible contributing factors include unusual MAF sensor behavior, an intake restriction, or a related sensor issue.\n\nThis does not confirm a mechanical fault. Further inspection is recommended if the behavior persists.',
      isUser: false,
      timestamp: DateTime(2025, 8, 24, 12, 30),
      evidence: [
        'MAF readings',
        'Engine Load',
        'Throttle Position',
        'Historical vehicle data',
        'Diagnostic code',
        'Automotive knowledge base',
      ],
      isRAGSupported: true,
    ),
  ];

  static const suggestedQuestions = [
    'What does this code mean?',
    'What should I check first?',
    'Has my vehicle\'s health changed?',
    'Show recent anomalies',
  ];

  static const mockAIResponses = {
    'warning': 'An airflow-related anomaly was detected because the vehicle\'s current telemetry differs from its learned operating pattern under similar conditions.\n\nPossible contributing factors include unusual MAF sensor behavior, an intake restriction, or a related sensor issue.\n\nThis does not confirm a mechanical fault. Further inspection is recommended if the behavior persists.',
    'code': 'The diagnostic code P0101 refers to "Mass or Volume Air Flow Circuit Range/Performance." This code is triggered when the ECU detects that the MAF sensor signal is outside the expected range.\n\nThis could be caused by a dirty or faulty MAF sensor, an air leak in the intake system, or a wiring issue. It is recommended to inspect the MAF sensor and air intake system.',
    'check': 'Based on the current diagnostic data, here are the recommended steps:\n\n1. Inspect the air intake system for leaks or blockages.\n2. Check the MAF sensor for contamination or damage.\n3. Verify all sensor connections are secure.\n4. Clear the code and monitor if it returns.\n5. If the issue persists, consult a qualified mechanic.',
    'health': 'Your vehicle\'s health score has decreased from 94 to 87 over the past two weeks. The primary factor is the airflow-related anomaly detected on August 24th.\n\nAll other systems (Engine, Cooling, Sensors, Electrical, Transmission) continue to operate within normal parameters.',
    'anomal': 'Currently, there is one active anomaly:\n\n\u26a0 Air Intake Behavior (Moderate)\nDetected: August 24, 2025 at 12:28 PM\n\nThe airflow-related telemetry differs from your vehicle\'s learned baseline. This is accompanied by diagnostic code P0101.',
    'default': 'Based on the available vehicle telemetry and diagnostic data, I can help you understand your vehicle\'s current condition.\n\nYour vehicle currently has one moderate anomaly related to the air intake system. All other systems are operating normally.\n\nWould you like me to explain any specific aspect of your vehicle\'s health?',
  };
}
