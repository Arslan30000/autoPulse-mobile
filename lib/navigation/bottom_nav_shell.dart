import 'package:flutter/material.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/services/role_service.dart';
import 'package:autosense_ai/screens/home/home_screen.dart';
import 'package:autosense_ai/screens/live/live_monitor_screen.dart';
import 'package:autosense_ai/screens/health/vehicle_health_screen.dart';
import 'package:autosense_ai/screens/diagnostics/diagnostics_screen.dart';
import 'package:autosense_ai/screens/ai/ai_assistant_screen.dart';
import 'package:autosense_ai/screens/profile/profile_screen.dart';
import 'package:autosense_ai/screens/mechanic/mechanic_home_screen.dart';
import 'package:autosense_ai/screens/mechanic/mechanic_telemetry_screen.dart';
import 'package:autosense_ai/screens/mechanic/mechanic_ai_screen.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _currentIndex = 0;

  List<Widget> get _screens {
    if (RoleService().isCarOwner) {
      return const [
        HomeScreen(),
        LiveMonitorScreen(),
        VehicleHealthScreen(),
        AIAssistantScreen(),
        ProfileScreen(),
      ];
    } else {
      return const [
        MechanicHomeScreen(),
        MechanicTelemetryScreen(),
        DiagnosticsScreen(),
        MechanicAIScreen(),
        ProfileScreen(),
      ];
    }
  }

  List<BottomNavigationBarItem> get _navItems {
    if (RoleService().isCarOwner) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.speed_rounded), label: 'Live'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: 'Health'),
        BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_rounded), label: 'AI'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.speed_rounded), label: 'Telemetry'),
        BottomNavigationBarItem(icon: Icon(Icons.build_rounded), label: 'Diagnostics'),
        BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_rounded), label: 'AI'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: _navItems,
        ),
      ),
    );
  }
}
