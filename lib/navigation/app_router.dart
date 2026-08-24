import 'package:flutter/material.dart';
import 'package:autosense_ai/screens/splash/splash_screen.dart';
import 'package:autosense_ai/screens/onboarding/onboarding_screen.dart';
import 'package:autosense_ai/screens/auth/login_screen.dart';
import 'package:autosense_ai/screens/vehicle/add_vehicle_screen.dart';
import 'package:autosense_ai/screens/live/live_monitor_screen.dart';
import 'package:autosense_ai/screens/health/vehicle_health_screen.dart';
import 'package:autosense_ai/screens/diagnostics/diagnostic_detail_screen.dart';
import 'package:autosense_ai/screens/ai/ai_assistant_screen.dart';
import 'package:autosense_ai/screens/history/health_history_screen.dart';
import 'package:autosense_ai/screens/reports/drive_report_screen.dart';
import 'package:autosense_ai/navigation/bottom_nav_shell.dart';
import 'package:autosense_ai/models/diagnostic.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String addVehicle = '/add-vehicle';
  static const String main = '/main';
  static const String live = '/live';
  static const String vehicleHealth = '/vehicle-health';
  static const String diagnosticDetail = '/diagnostic-detail';
  static const String aiAssistant = '/ai-assistant';
  static const String healthHistory = '/health-history';
  static const String driveReport = '/drive-report';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
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
