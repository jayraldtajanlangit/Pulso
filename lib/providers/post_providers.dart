import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_controller.dart';
import '../post/post_model.dart';
import '../post/post_repository.dart';
import 'supabase_providers.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabasePostRepository(client);
});

final postControllerProvider =
    NotifierProvider<PostController, PostState>(PostController.new);

/// Per-user post list — completely isolated from the global feed state.
final profilePostsProvider =
    FutureProvider.family<List<PostModel>, String>((ref, userId) async {
  final repository = ref.watch(postRepositoryProvider);
  return repository.getPosts(userId);
});
