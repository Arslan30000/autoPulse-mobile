import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autopulse_ai/core/config/supabase_config.dart';
import 'package:autopulse_ai/core/theme/app_theme.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/services/account_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const backend = SupabaseConfig.fromEnvironment();
  backend.validate();
  if (backend.isConfigured) {
    await Supabase.initialize(
      url: backend.url,
      publishableKey: backend.publicKey,
    );
    AccountService.instance.configure(Supabase.instance.client);
  }
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
