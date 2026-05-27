import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../like/like_controller.dart';
import '../like/like_repository.dart';
import 'supabase_providers.dart';

final likeRepositoryProvider = Provider<LikeRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseLikeRepository(client);
});

final likeControllerProvider =
    NotifierProvider<LikeController, LikeState>(LikeController.new);
