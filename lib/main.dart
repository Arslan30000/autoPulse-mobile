import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/core/config/supabase_config.dart';
import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/account_data_service.dart';
import 'package:flutter/foundation.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/services/recording_sync_service.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';
import 'package:autopulse_ai/repositories/cloud_recording_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await SupabaseConfig.load();
  backend.validate();
  if (backend.isConfigured) {
    await Supabase.initialize(
      url: backend.url,
      publishableKey: backend.publicKey,
    );
    AccountService.instance.configure(Supabase.instance.client);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final sync = RecordingSyncService(
        store: ObdController.instance.repository as RecordingStore,
        cloud: SupabaseRecordingRepository(Supabase.instance.client),
      );
      RecordingSyncService.instance = sync;
      sync.start(Supabase.instance.client);
    }
  }
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoPulse_ai',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
