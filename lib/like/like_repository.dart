import 'package:supabase_flutter/supabase_flutter.dart';

abstract class LikeRepository {
  /// Returns true if the post is now liked by the user, false if unliked.
  Future<bool> toggleLike({required String postId, required String userId});

  Future<bool> isLikedByUser({
    required String postId,
    required String userId,
  });

  Future<int> getLikeCount(String postId);

  Future<Map<String, int>> getLikeCountsForPosts(List<String> postIds);

  Future<Set<String>> getLikedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  });

  /// Subscribe to realtime INSERT/DELETE events on the likes table.
  /// The callback fires with the affected postId so the UI can refresh.
  RealtimeChannel subscribeToLikes({
    required void Function(String postId) onLikeChanged,
  });
}

class SupabaseLikeRepository implements LikeRepository {
  const SupabaseLikeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final existing = await _client
        .from('likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return false;
    }

    await _client.from('likes').insert({
      'post_id': postId,
      'user_id': userId,
    });
    return true;
  }

  @override
  Future<bool> isLikedByUser({
    required String postId,
    required String userId,
  }) async {
    final response = await _client
        .from('likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    return response != null;
  }

  @override
  Future<int> getLikeCount(String postId) async {
    final response = await _client
        .from('likes')
        .select('id')
        .eq('post_id', postId)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<Map<String, int>> getLikeCountsForPosts(List<String> postIds) async {
    if (postIds.isEmpty) return {};

    final response = await _client
        .from('likes')
        .select('post_id')
        .inFilter('post_id', postIds);

    final counts = <String, int>{for (final id in postIds) id: 0};
    for (final row in response as List) {
      final postId = (row as Map<String, dynamic>)['post_id'] as String;
      counts[postId] = (counts[postId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<Set<String>> getLikedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) return {};

    final response = await _client
        .from('likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);

    return (response as List)
        .map((row) => (row as Map<String, dynamic>)['post_id'] as String)
        .toSet();
  }

  @override
  RealtimeChannel subscribeToLikes({
    required void Function(String postId) onLikeChanged,
  }) {
    return _client
        .channel('posts_likes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'likes',
          callback: (payload) {
            final postId = payload.newRecord['post_id'] as String?;
            if (postId != null) onLikeChanged(postId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'likes',
          callback: (payload) {
            final postId = payload.oldRecord['post_id'] as String?;
            if (postId != null) onLikeChanged(postId);
          },
        )
        .subscribe();
  }
}
