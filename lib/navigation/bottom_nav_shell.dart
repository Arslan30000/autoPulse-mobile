import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/services/role_service.dart';
import 'package:autopulse_ai/screens/home/home_screen.dart';
import 'package:autopulse_ai/screens/live/live_monitor_screen.dart';
import 'package:autopulse_ai/screens/health/vehicle_health_screen.dart';
import 'package:autopulse_ai/screens/diagnostics/diagnostics_screen.dart';
import 'package:autopulse_ai/screens/ai/ai_assistant_screen.dart';
import 'package:autopulse_ai/screens/profile/profile_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_home_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_telemetry_screen.dart';
import 'package:autopulse_ai/screens/mechanic/mechanic_ai_screen.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _currentIndex = 0;
  final Set<int> _visited = {0};
  LocalHistoryEntry? _tabHistory;
  bool _disposing = false;

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    if (index == 0) {
      _tabHistory?.remove();
      return;
    }
    // Tabs share a route. Give that route a local back destination so both
    // Android back and the app bar return to Home before leaving the app.
    if (_tabHistory == null) {
      _tabHistory = LocalHistoryEntry(
        onRemove: () {
          _tabHistory = null;
          if (!_disposing && mounted) setState(() => _currentIndex = 0);
        },
      );
      ModalRoute.of(context)!.addLocalHistoryEntry(_tabHistory!);
    }
    setState(() {
      _visited.add(index);
      _currentIndex = index;
    });
  }

  @override
  void dispose() {
    _disposing = true;
    _tabHistory?.remove();
    super.dispose();
  }

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
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite_rounded),
          label: 'Health',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome_rounded),
          label: 'AI',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.speed_rounded),
          label: 'Telemetry',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.build_rounded),
          label: 'Diagnostics',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome_rounded),
          label: 'AI',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (var i = 0; i < screens.length; i++)
            _visited.contains(i)
                ? TickerMode(enabled: i == _currentIndex, child: screens[i])
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: .18),
          height: 72,
          elevation: 0,
          destinations: [
            for (final item in _navItems)
              NavigationDestination(icon: item.icon, label: item.label ?? ''),
          ],
        ),
      ),
    );
  }
}
