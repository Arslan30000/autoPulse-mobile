import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:autopulse_ai/core/config/supabase_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normal launch loads bundled public backend settings', () async {
    final config = await SupabaseConfig.load(bundle: _PublicConfigBundle());
    expect(config.url, 'https://example.supabase.co');
    expect(config.publicKey, 'public-test-key');
    expect(config.isConfigured, isTrue);
  });
  test('missing configuration allows the mock prototype', () {
    const config = SupabaseConfig(url: '', publicKey: '');
    expect(config.isConfigured, isFalse);
    expect(config.validate, returnsNormally);
  });

  test('partial configuration is rejected', () {
    const config = SupabaseConfig(
      url: 'https://example.supabase.co',
      publicKey: '',
    );
    expect(config.validate, throwsArgumentError);
  });

  test('HTTPS project and public key are accepted', () {
    const config = SupabaseConfig(
      url: 'https://example.supabase.co',
      publicKey: 'public-test-key',
    );
    expect(config.isConfigured, isTrue);
    expect(config.validate, returnsNormally);
  });

  test('insecure URL and secret keys are rejected', () {
    expect(
      const SupabaseConfig(
        url: 'http://example.com',
        publicKey: 'public',
      ).validate,
      throwsArgumentError,
    );
    expect(
      SupabaseConfig(
        url: 'https://example.supabase.co',
        publicKey: <String>['sb_', 'secret_example'].join(),
      ).validate,
      throwsArgumentError,
    );
  });
}

class _PublicConfigBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    expect(key, 'assets/supabase.public.json');
    return '{"url":"https://example.supabase.co","publicKey":"public-test-key"}';
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}
