import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/role_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await fonts.load();
  });
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AccountService.instance.configure(null);
    RoleService().setRole(UserRole.carOwner);
  });
  for (final width in [320.0, 414.0]) {
    for (final route in [
      AppRouter.roleSelection,
      AppRouter.addVehicle,
      AppRouter.main,
      AppRouter.live,
      AppRouter.vehicleHealth,
      AppRouter.diagnosticDetail,
      AppRouter.diagnostics,
      AppRouter.aiAssistant,
      AppRouter.healthHistory,
      AppRouter.driveReport,
      AppRouter.mechanicTelemetry,
      AppRouter.mechanicAnomaly,
      AppRouter.mechanicDtc,
      AppRouter.mechanicAI,
      AppRouter.mechanicReport,
      AppRouter.mechanicHistory,
    ]) {
      testWidgets('$route renders and scrolls at width $width', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 740);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(),
            onGenerateRoute: AppRouter.generateRoute,
          ),
        );
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pushNamed(
          route,
          arguments: route == AppRouter.diagnosticDetail
              ? MockData.anomalies.first
              : null,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        final scrolls = find.byType(Scrollable);
        if (scrolls.evaluate().isNotEmpty) {
          await tester.drag(scrolls.first, const Offset(0, -600));
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    }
  }
}
