import 'package:flutter/material.dart';
import 'package:autopulse_ai/screens/splash/splash_screen.dart';
import 'package:autopulse_ai/screens/onboarding/onboarding_screen.dart';
import 'package:autopulse_ai/screens/role/role_selection_screen.dart';
import 'package:autopulse_ai/screens/vehicle/add_vehicle_screen.dart';
import 'package:autopulse_ai/screens/live/live_monitor_screen.dart';
import 'package:autopulse_ai/screens/health/vehicle_health_screen.dart';
import 'package:autopulse_ai/screens/diagnostics/diagnostic_detail_screen.dart';
import 'package:autopulse_ai/screens/ai/ai_assistant_screen.dart';
import 'package:autopulse_ai/screens/history/health_history_screen.dart';
import 'package:autopulse_ai/screens/reports/drive_report_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_home_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_telemetry_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_anomaly_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_dtc_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_ai_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_report_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_history_screen.dart';
import 'package:autopulse_ai/navigation/bottom_nav_shell.dart';
import 'package:autopulse_ai/models/diagnostic.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String roleSelection = '/role-selection';
  static const String addVehicle = '/add-vehicle';
  static const String main = '/main';
  static const String live = '/live';
  static const String vehicleHealth = '/vehicle-health';
  static const String diagnosticDetail = '/diagnostic-detail';
  static const String aiAssistant = '/ai-assistant';
  static const String healthHistory = '/health-history';
  static const String driveReport = '/drive-report';
  // Mechanic-specific
  static const String mechanicTelemetry = '/mechanic-telemetry';
  static const String mechanicAnomaly = '/mechanic-anomaly';
  static const String mechanicDtc = '/mechanic-dtc';
  static const String mechanicAI = '/mechanic-ai';
  static const String mechanicReport = '/mechanic-report';
  static const String mechanicHistory = '/mechanic-history';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());
      case addVehicle:
        return MaterialPageRoute(builder: (_) => const AddVehicleScreen());
      case main:
        return MaterialPageRoute(builder: (_) => const BottomNavShell());
      case live:
        return MaterialPageRoute(builder: (_) => const LiveMonitorScreen());
      case vehicleHealth:
        return MaterialPageRoute(builder: (_) => const VehicleHealthScreen());
      case diagnosticDetail:
        final anomaly = settings.arguments as Anomaly;
        return MaterialPageRoute(
          builder: (_) => DiagnosticDetailScreen(anomaly: anomaly),
        );
      case aiAssistant:
        return MaterialPageRoute(builder: (_) => const AIAssistantScreen());
      case healthHistory:
        return MaterialPageRoute(builder: (_) => const HealthHistoryScreen());
      case driveReport:
        return MaterialPageRoute(builder: (_) => const DriveReportScreen());
      case mechanicTelemetry:
        return MaterialPageRoute(builder: (_) => const MechanicTelemetryScreen());
      case mechanicAnomaly:
        return MaterialPageRoute(builder: (_) => const MechanicAnomalyScreen());
      case mechanicDtc:
        return MaterialPageRoute(builder: (_) => const MechanicDtcScreen());
      case mechanicAI:
        return MaterialPageRoute(builder: (_) => const MechanicAIScreen());
      case mechanicReport:
        return MaterialPageRoute(builder: (_) => const MechanicReportScreen());
      case mechanicHistory:
        return MaterialPageRoute(builder: (_) => const MechanicHistoryScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
