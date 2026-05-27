import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bookmark/bookmark_controller.dart';
import '../bookmark/bookmark_repository.dart';
import '../post/post_model.dart';
import 'post_providers.dart';
import 'supabase_providers.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseBookmarkRepository(client);
});

final bookmarkControllerProvider =
    NotifierProvider<BookmarkController, BookmarkState>(BookmarkController.new);

final savedPostsProvider =
    FutureProvider.family<List<PostModel>, String>((ref, userId) async {
  final bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
  final postRepo = ref.watch(postRepositoryProvider);
  final postIds = await bookmarkRepo.getAllBookmarkedPostIds(userId: userId);
  if (postIds.isEmpty) return [];
  return postRepo.getPostsByIds(postIds);
});
