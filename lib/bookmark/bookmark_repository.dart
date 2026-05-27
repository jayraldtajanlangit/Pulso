import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BookmarkRepository {
  Future<bool> toggleBookmark({
    required String postId,
    required String userId,
  });

  Future<Set<String>> getBookmarkedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  });

  Future<List<String>> getAllBookmarkedPostIds({required String userId});
}

class SupabaseBookmarkRepository implements BookmarkRepository {
  const SupabaseBookmarkRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> toggleBookmark({
    required String postId,
    required String userId,
  }) async {
    final existing = await _client
        .from('bookmarks')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('bookmarks')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return false;
    }

    await _client.from('bookmarks').insert({
      'post_id': postId,
      'user_id': userId,
    });
    return true;
  }

  @override
  Future<Set<String>> getBookmarkedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) return {};
    final response = await _client
        .from('bookmarks')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);
    return (response as List)
        .map((row) => (row as Map<String, dynamic>)['post_id'] as String)
        .toSet();
  }

  @override
  Future<List<String>> getAllBookmarkedPostIds({required String userId}) async {
    final response = await _client
        .from('bookmarks')
        .select('post_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => (row as Map<String, dynamic>)['post_id'] as String)
        .toList();
  }
}
