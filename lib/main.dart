import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:autopulse_ai/core/config/firebase_config.dart';
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
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await (ObdController.instance.repository as SqliteObdRecordingRepository)
          .recoverInterruptedRecordings();
    } catch (error) {
      debugPrint('Recording recovery unavailable: $error');
      // Keep the app's storage error/retry and offline navigation accessible.
    }
  }
  if (backend.isConfigured) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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
      initialRoute: '/',
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
