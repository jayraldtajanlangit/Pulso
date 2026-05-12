import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';

final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => const SupabaseConfig.fromEnvironment(),
);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    final supabase = Supabase.instance;
    return supabase.isInitialized ? supabase.client : null;
  } on AssertionError {
    return null;
  }
});
