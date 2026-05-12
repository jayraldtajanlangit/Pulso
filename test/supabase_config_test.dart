import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/supabase_config.dart';

void main() {
  group('SupabaseConfig', () {
    test('is not configured when credentials are blank', () {
      const config = SupabaseConfig(url: ' ', publishableKey: '');

      expect(config.isConfigured, isFalse);
    });

    test('is configured when url and publishable key are present', () {
      const config = SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
      );

      expect(config.isConfigured, isTrue);
    });
  });
}
