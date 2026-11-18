import 'package:autopulse_ai/core/config/mobile_platform.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autopulse_ai/core/config/firebase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/core/config/supabase_config.dart';
import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/core/widgets/dtc_alert_host.dart';
import 'package:autopulse_ai/core/widgets/context_change_banner.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/account_data_service.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/services/driving_context/context_model_loader.dart';
import 'package:autopulse_ai/services/diagnostics/vehicle_diagnostics.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final model = await ContextModelLoader.load();
    if (model != null) {
      ObdController.instance.drivingContext.useEvaluator(model);
    }
  } catch (error) {
    debugPrint('Context model unavailable; using provisional rules: $error');
  }
  final backend = await SupabaseConfig.load();
  backend.validate();
  if (supportsMobileRecordings) {
    try {
      await (ObdController.instance.repository as SqliteObdRecordingRepository)
          .recoverInterruptedRecordings();
    } catch (error) {
      debugPrint('Recording recovery unavailable: $error');
      // Keep the app's storage error/retry and offline navigation accessible.
    }
  }
  final firebaseOptions = FirebaseConfig.options;
  if (backend.isConfigured && firebaseOptions != null) {
    await Firebase.initializeApp(options: firebaseOptions);
    final client = SupabaseClient(
      backend.url,
      backend.publicKey,
      accessToken: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || !user.emailVerified) return null;
        return user.getIdToken();
      },
    );
    await AccountService.instance.configureFirebase(
      FirebaseAuth.instance,
      client,
      SupabaseClient(
        backend.url,
        backend.publicKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    if (supportsMobileRecordings) {
      final sync = RecordingSyncService(
        store: ObdController.instance.repository as RecordingStore,
        cloud: SupabaseRecordingRepository(
          client,
          accountOwner: () => AccountService.instance.userId,
          compressed: true,
        ),
        batchSize: 1000,
      );
      RecordingSyncService.instance = sync;
      sync.start(client, accountChanges: AccountService.instance.changes);
    }
  }
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (supportsMobileRecordings) {
    final diagnostics = VehicleDiagnostics(
      ObdController.instance.repository as SqliteObdRecordingRepository,
    );
    VehicleDiagnostics.instance = diagnostics;
    AccountService.instance.changes.listen(
      (_) => unawaited(diagnostics.refresh()),
    );
    unawaited(diagnostics.refresh());
  }
  AccountDataService.instance.start();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AutoPulseApp());
}

class AutoPulseApp extends StatelessWidget {
  const AutoPulseApp({super.key});
  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoPulse_ai',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      onGenerateRoute: AppRouter.generateRoute,
      builder: (context, child) => DtcAlertHost(
        monitor: ObdController.instance.diagnostics,
        passiveAlert: ContextChangeBanner(
          controller: ObdController.instance.drivingContext,
        ),
        onViewCodes: () =>
            _navigatorKey.currentState?.pushNamed(AppRouter.diagnostics),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
