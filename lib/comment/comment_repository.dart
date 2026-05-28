import 'package:supabase_flutter/supabase_flutter.dart';

import 'comment_model.dart';

abstract class CommentRepository {
  Future<List<CommentModel>> fetchComments(String postId);

  /// Fetch all replies that belong to [parentCommentId], ordered oldest-first.
  Future<List<CommentModel>> fetchReplies(String parentCommentId);

  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String body,
    String? parentCommentId,
  });

  Future<void> deleteComment(String commentId);

  Future<int> getCommentCount(String postId);

  Future<Map<String, int>> getCommentCountsForPosts(List<String> postIds);

  /// Hydrate like counts + current-user like state + reply counts for a list
  /// of comments. Returns the same list with the metadata fields filled in.
  Future<List<CommentModel>> hydrateMetadata(
    List<CommentModel> comments, {
    required String currentUserId,
  });

  /// Toggle a like on [commentId] for [userId]. Returns true if now liked.
  Future<bool> toggleCommentLike({
    required String commentId,
    required String userId,
  });

  /// Subscribe to realtime INSERT events on the comments table.
  RealtimeChannel subscribeToComments({
    required String postId,
    required void Function(CommentModel comment) onCommentAdded,
    void Function(String commentId)? onCommentDeleted,
  });

  /// Subscribe to realtime INSERT/DELETE events on the comments table for
  /// ALL posts — used to keep feed-level comment counts in sync without
  /// requiring the user to open every post's comment list.
  RealtimeChannel subscribeToAllComments({
    required void Function(String postId) onCommentAdded,
    required void Function(String postId) onCommentDeleted,
  });
}

class SupabaseCommentRepository implements CommentRepository {
  const SupabaseCommentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CommentModel>> fetchComments(String postId) async {
    // Only top-level comments (parent_comment_id IS NULL). Replies are
    // fetched on-demand when the user expands "View N replies".
    final response = await _client
        .from('comments')
        .select('*, profiles!user_id(username, display_name, avatar_url)')
        .eq('post_id', postId)
        .filter('parent_comment_id', 'is', null)
        .order('created_at', ascending: true);

    return (response as List)
        .map((row) => CommentModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CommentModel>> fetchReplies(String parentCommentId) async {
    final response = await _client
        .from('comments')
        .select('*, profiles!user_id(username, display_name, avatar_url)')
        .eq('parent_comment_id', parentCommentId)
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
    String? parentCommentId,
  }) async {
    final response = await _client
        .from('comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'body': body,
          if (parentCommentId != null) 'parent_comment_id': parentCommentId,
        })
        .select('*, profiles!user_id(username, display_name, avatar_url)')
        .single();
    return CommentModel.fromMap(response);
  }

  @override
  Future<List<CommentModel>> hydrateMetadata(
    List<CommentModel> comments, {
    required String currentUserId,
  }) async {
    if (comments.isEmpty) return comments;

    final ids = comments.map((c) => c.id).toList();

    // Like counts + which ones current user liked.
    final likeRows = await _client
        .from('comment_likes')
        .select('comment_id, user_id')
        .inFilter('comment_id', ids);

    final likeCounts = <String, int>{for (final id in ids) id: 0};
    final likedByMe = <String>{};
    for (final r in (likeRows as List).cast<Map<String, dynamic>>()) {
      final cid = r['comment_id'] as String;
      likeCounts[cid] = (likeCounts[cid] ?? 0) + 1;
      if (r['user_id'] == currentUserId) likedByMe.add(cid);
    }

    // Reply counts: only relevant for top-level comments.
    final topLevelIds =
        comments.where((c) => !c.isReply).map((c) => c.id).toList();
    final replyCounts = <String, int>{for (final id in topLevelIds) id: 0};
    if (topLevelIds.isNotEmpty) {
      final replyRows = await _client
          .from('comments')
          .select('parent_comment_id')
          .inFilter('parent_comment_id', topLevelIds);
      for (final r in (replyRows as List).cast<Map<String, dynamic>>()) {
        final parent = r['parent_comment_id'] as String?;
        if (parent != null) {
          replyCounts[parent] = (replyCounts[parent] ?? 0) + 1;
        }
      }
    }

    return comments
        .map(
          (c) => c.copyWith(
            likeCount: likeCounts[c.id] ?? 0,
            isLikedByMe: likedByMe.contains(c.id),
            replyCount: c.isReply ? 0 : (replyCounts[c.id] ?? 0),
          ),
        )
        .toList();
  }

  @override
  Future<bool> toggleCommentLike({
    required String commentId,
    required String userId,
  }) async {
    final existing = await _client
        .from('comment_likes')
        .select('id')
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
      return false;
    }

    await _client.from('comment_likes').insert({
      'comment_id': commentId,
      'user_id': userId,
    });
    return true;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
  }

  @override
  Future<int> getCommentCount(String postId) async {
    // Count includes both top-level comments and their replies — matches
    // Instagram's "N comments" total under the post.
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

  @override
  RealtimeChannel subscribeToAllComments({
    required void Function(String postId) onCommentAdded,
    required void Function(String postId) onCommentDeleted,
  }) {
    return _client
        .channel('all_comments_counts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          callback: (payload) {
            final postId = payload.newRecord['post_id'] as String?;
            if (postId != null) onCommentAdded(postId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'comments',
          callback: (payload) {
            final postId = payload.oldRecord['post_id'] as String?;
            if (postId != null) onCommentDeleted(postId);
          },
        )
        .subscribe();
  }
}
