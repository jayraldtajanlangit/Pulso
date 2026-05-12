import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  const SupabaseConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  final String url;
  final String publishableKey;

  bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SupabaseConfig &&
            other.url == url &&
            other.publishableKey == publishableKey;
  }

  @override
  int get hashCode => Object.hash(url, publishableKey);
}

Future<bool> initializeSupabase([
  SupabaseConfig config = const SupabaseConfig.fromEnvironment(),
]) async {
  if (!config.isConfigured) {
    return false;
  }

  await Supabase.initialize(
    url: config.url.trim(),
    anonKey: config.publishableKey.trim(),
  );
  return true;
}
