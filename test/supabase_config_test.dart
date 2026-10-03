import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/core/config/supabase_config.dart';

void main() {
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
      publicKey: 'sb_publishable_example',
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
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publicKey: 'sb_secret_example',
      ).validate,
      throwsArgumentError,
    );
  });
}
