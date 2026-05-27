import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../follow/follow_controller.dart';
import '../follow/follow_repository.dart';
import 'supabase_providers.dart';

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseFollowRepository(client);
});

final followControllerProvider =
    NotifierProvider<FollowController, FollowState>(FollowController.new);
