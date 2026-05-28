import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_repository.dart';
import 'supabase_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseProfileRepository(client);
});
