import 'package:supabase_flutter/supabase_flutter.dart';

import 'comment_model.dart';

abstract class CommentRepository {
  Future<List<CommentModel>> fetchComments(String postId);

  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String body,
  });

  Future<void> deleteComment(String commentId);

  Future<int> getCommentCount(String postId);

  Future<Map<String, int>> getCommentCountsForPosts(List<String> postIds);

  /// Subscribe to realtime INSERT events on the comments table.
  RealtimeChannel subscribeToComments({
    required String postId,
    required void Function(CommentModel comment) onCommentAdded,
    void Function(String commentId)? onCommentDeleted,
  });
}

class SupabaseCommentRepository implements CommentRepository {
  const SupabaseCommentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CommentModel>> fetchComments(String postId) async {
    final response = await _client
        .from('comments')
        .select('*, profiles!user_id(username, display_name, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((row) => CommentModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String body,
  }) async {
    final response = await _client
        .from('comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'body': body,
        })
        .select('*, profiles!user_id(username, display_name, avatar_url)')
        .single();
    return CommentModel.fromMap(response);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
  }

  @override
  Future<int> getCommentCount(String postId) async {
    final response = await _client
        .from('comments')
        .select('id')
        .eq('post_id', postId)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<Map<String, int>> getCommentCountsForPosts(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};

    final response = await _client
        .from('comments')
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
  RealtimeChannel subscribeToComments({
    required String postId,
    required void Function(CommentModel comment) onCommentAdded,
    void Function(String commentId)? onCommentDeleted,
  }) {
    return _client
        .channel('post_comments_$postId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) async {
            // Re-fetch with profile join since realtime payload doesn't include joins.
            final row = await _client
                .from('comments')
                .select(
                  '*, profiles!user_id(username, display_name, avatar_url)',
                )
                .eq('id', payload.newRecord['id'] as String)
                .maybeSingle();
            if (row != null) {
              onCommentAdded(CommentModel.fromMap(row));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) {
            final commentId = payload.oldRecord['id'] as String?;
            if (commentId != null) onCommentDeleted?.call(commentId);
          },
        )
        .subscribe();
  }
}
