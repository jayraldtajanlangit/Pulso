import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/providers/supabase_providers.dart';
import 'package:pulso/supabase_config.dart';

void main() {
  test('supabase config provider reads environment config by default', () {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    expect(
      container.read(supabaseConfigProvider),
      const SupabaseConfig.fromEnvironment(),
    );
  });

  test('supabase client provider is null until Supabase is initialized', () {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    expect(container.read(supabaseClientProvider), isNull);
  });
}
