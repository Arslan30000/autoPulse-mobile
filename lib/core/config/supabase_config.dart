import 'dart:convert';

import 'package:flutter/services.dart';

class SupabaseConfig {
  final String url;
  final String publicKey;

  const SupabaseConfig({required this.url, required this.publicKey});

  const SupabaseConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      publicKey = const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  bool get isConfigured => url.isNotEmpty && publicKey.isNotEmpty;

  /// Public client settings are safe to bundle; database access still uses RLS.
  /// Explicit build definitions take precedence over the project's defaults.
  static Future<SupabaseConfig> load({AssetBundle? bundle}) async {
    if (const bool.fromEnvironment('AUTOPULSE_OFFLINE')) {
      return const SupabaseConfig(url: '', publicKey: '');
    }
    const environment = SupabaseConfig.fromEnvironment();
    if (environment.url.isNotEmpty || environment.publicKey.isNotEmpty) {
      environment.validate();
      return environment;
    }
    final values = jsonDecode(
      await (bundle ?? rootBundle).loadString('assets/supabase.public.json'),
    ) as Map<String, dynamic>;
    final config = SupabaseConfig(
      url: values['url'] as String,
      publicKey: values['publicKey'] as String,
    );
    config.validate();
    return config;
  }

  void validate() {
    if (url.isEmpty && publicKey.isEmpty) return;
    if (!isConfigured) {
      throw ArgumentError(
        'Supply both SUPABASE_URL and a public Supabase key.',
      );
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError('SUPABASE_URL must be an HTTPS project URL.');
    }
    if (publicKey.startsWith('sb_secret_')) {
      throw ArgumentError('Never use a Supabase secret key in the mobile app.');
    }
  }
}
