import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/core/widgets/obd_connection_panel.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/navigation/bottom_nav_shell.dart';
import 'package:autopulse_ai/screens/home/home_screen.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/role_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AccountService.instance.configure(null);
    RoleService().setRole(UserRole.carOwner);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const BottomNavShell(),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('system and toolbar back return tabs to Home', (tester) async {
    await mount(tester);
    for (final label in ['Live', 'Health', 'AI', 'Profile']) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.byType(HomeScreen), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('pushed Live route returns to Home and preserves route name', (
    tester,
  ) async {
    await mount(tester);
    await tester.ensureVisible(find.text('Live Monitor'));
    await tester.tap(find.text('Live Monitor'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      ModalRoute.of(tester.element(find.text('Live Monitor')))?.settings.name,
      AppRouter.live,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'Home and Profile open the same Bluetooth sheet; back closes sheet first',
    (tester) async {
      await mount(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Connect'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ObdConnectionPanel), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('OBD-II connection'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ObdConnectionPanel), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
