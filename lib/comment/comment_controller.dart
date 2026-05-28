import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/comment_providers.dart';
import '../providers/notification_providers.dart';
import 'comment_model.dart';
import 'comment_repository.dart';

class CommentThreadState {
  const CommentThreadState({
    required this.isLoading,
    required this.isSubmitting,
    required this.comments,
    this.repliesByParent = const {},
    this.errorMessage,
  });

  const CommentThreadState.initial()
    : isLoading = false,
      isSubmitting = false,
      comments = const [],
      repliesByParent = const {},
      errorMessage = null;

  final bool isLoading;
  final bool isSubmitting;
  final List<CommentModel> comments;
  /// Expanded replies for each parent comment id. Absent key = "not loaded /
  /// collapsed". Present key with an empty list = "loaded, no replies".
  final Map<String, List<CommentModel>> repliesByParent;
  final String? errorMessage;

  CommentThreadState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<CommentModel>? comments,
    Map<String, List<CommentModel>>? repliesByParent,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CommentThreadState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      comments: comments ?? this.comments,
      repliesByParent: repliesByParent ?? this.repliesByParent,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class CommentState {
  const CommentState({
    required this.threads,
    required this.counts,
  });

  const CommentState.initial() : threads = const {}, counts = const {};

  final Map<String, CommentThreadState> threads;
  final Map<String, int> counts;

  CommentThreadState threadFor(String postId) =>
      threads[postId] ?? const CommentThreadState.initial();

  int countFor(String postId) => counts[postId] ?? 0;

  CommentState copyWith({
    Map<String, CommentThreadState>? threads,
    Map<String, int>? counts,
  }) {
    return CommentState(
      threads: threads ?? this.threads,
      counts: counts ?? this.counts,
    );
  }
}

class CommentController extends Notifier<CommentState> {
  final Map<String, RealtimeChannel> _channels = {};
  RealtimeChannel? _globalCountsChannel;

  CommentRepository get _repository => ref.read(commentRepositoryProvider);

  @override
  CommentState build() {
    ref.onDispose(() {
      try {
        final client = Supabase.instance.client;
        for (final channel in _channels.values) {
          client.removeChannel(channel);
        }
        final global = _globalCountsChannel;
        if (global != null) client.removeChannel(global);
      } catch (_) {
        // Supabase not initialized (e.g., during unit tests).
      }
      _channels.clear();
      _globalCountsChannel = null;
    });
    return const CommentState.initial();
  }

  /// Subscribe once to ALL comment inserts/deletes so feed-level counts stay
  /// fresh across clients even when the user hasn't opened any post's
  /// comment list. Safe to call multiple times.
  void ensureGlobalCountsSubscription() {
    if (_globalCountsChannel != null) return;
    try {
      _globalCountsChannel = _repository.subscribeToAllComments(
        onCommentAdded: (postId) {
          // Only bump if we already know about this post — otherwise the
          // count would jump from undefined to 1 with no context.
          if (state.counts.containsKey(postId)) {
            final updated = Map<String, int>.from(state.counts);
            updated[postId] = (updated[postId] ?? 0) + 1;
            state = state.copyWith(counts: updated);
          }
        },
        onCommentDeleted: (postId) {
          if (state.counts.containsKey(postId)) {
            final updated = Map<String, int>.from(state.counts);
            updated[postId] =
                ((updated[postId] ?? 0) - 1).clamp(0, 1 << 31);
            state = state.copyWith(counts: updated);
          }
        },
      );
    } catch (e) {
      // Subscription is best-effort.
      // ignore: avoid_print
      print('[CommentController] global counts subscription failed: $e');
    }
  }

  /// Load comments for a single post and start a realtime subscription.
  Future<void> loadComments(String postId) async {
    _setThread(
      postId,
      state.threadFor(postId).copyWith(isLoading: true, clearError: true),
    );
    try {
      final raw = await _repository.fetchComments(postId);
      final currentUserId = _currentUserId;
      final comments = currentUserId != null
          ? await _repository.hydrateMetadata(
              raw,
              currentUserId: currentUserId,
            )
          : raw;
      _setThread(
        postId,
        CommentThreadState(
          isLoading: false,
          isSubmitting: false,
          comments: comments,
        ),
      );
      // Total = top-level comments + their reply counts. Matches what the
      // server's getCommentCountsForPosts returns (all rows including replies).
      _setCount(postId, _countAll(comments));
      _ensureSubscription(postId);
    } catch (e) {
      _setThread(
        postId,
        state
            .threadFor(postId)
            .copyWith(isLoading: false, errorMessage: e.toString()),
      );
    }
  }

  /// Load comment counts for a batch of posts (used by feed).
  Future<void> loadCountsForPosts(List<String> postIds) async {
    if (postIds.isEmpty) return;
    try {
      final counts = await _repository.getCommentCountsForPosts(postIds);
      final updated = Map<String, int>.from(state.counts);
      counts.forEach((postId, count) => updated[postId] = count);
      state = state.copyWith(counts: updated);
    } catch (_) {
      // Silently ignore — counts will refresh on next load.
    }
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String body,
    String? postOwnerId,
    String? parentCommentId,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      _setThread(
        postId,
        state
            .threadFor(postId)
            .copyWith(errorMessage: 'Comment cannot be empty.'),
      );
      return;
    }

    _setThread(
      postId,
      state
          .threadFor(postId)
          .copyWith(isSubmitting: true, clearError: true),
    );
    try {
      final created = await _repository.addComment(
        postId: postId,
        userId: userId,
        body: trimmed,
        parentCommentId: parentCommentId,
      );

      final thread = state.threadFor(postId);

      if (parentCommentId == null) {
        // Top-level comment: append to the list.
        final hasIt = thread.comments.any((c) => c.id == created.id);
        final next = hasIt ? thread.comments : [...thread.comments, created];
        _setThread(
          postId,
          thread.copyWith(isSubmitting: false, comments: next),
        );
        if (!hasIt) {
          _setCount(postId, state.countFor(postId) + 1);
        }
      } else {
        // Reply: bump the parent's replyCount and append to its loaded
        // replies bucket so the expanded thread updates immediately.
        final updatedComments = thread.comments
            .map(
              (c) => c.id == parentCommentId
                  ? c.copyWith(replyCount: c.replyCount + 1)
                  : c,
            )
            .toList();
        final updatedReplies =
            Map<String, List<CommentModel>>.from(thread.repliesByParent);
        final list = updatedReplies[parentCommentId];
        if (list != null) {
          updatedReplies[parentCommentId] = [...list, created];
        }
        _setThread(
          postId,
          thread.copyWith(
            isSubmitting: false,
            comments: updatedComments,
            repliesByParent: updatedReplies,
          ),
        );
        // Total just increases by one — the parent's replyCount is the only
        // source of truth for nested replies, not the expanded bucket size.
        _setCount(postId, state.countFor(postId) + 1);
      }

      if (postOwnerId != null && postOwnerId != userId) {
        try {
          await ref.read(notificationRepositoryProvider).insertNotification(
            recipientId: postOwnerId,
            actorId: userId,
            type: 'comment',
            postId: postId,
          );
        } catch (_) {}
      }
    } catch (e) {
      _setThread(
        postId,
        state.threadFor(postId).copyWith(
          isSubmitting: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Toggle a like on [commentId] under [postId]. Updates the local state
  /// optimistically.
  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    final thread = state.threadFor(postId);
    final updatedComments = thread.comments
        .map((c) => c.id == commentId
            ? c.copyWith(
                isLikedByMe: !c.isLikedByMe,
                likeCount: c.likeCount + (c.isLikedByMe ? -1 : 1),
              )
            : c)
        .toList();
    final updatedReplies = <String, List<CommentModel>>{
      for (final entry in thread.repliesByParent.entries)
        entry.key: entry.value
            .map((c) => c.id == commentId
                ? c.copyWith(
                    isLikedByMe: !c.isLikedByMe,
                    likeCount: c.likeCount + (c.isLikedByMe ? -1 : 1),
                  )
                : c)
            .toList(),
    };
    _setThread(
      postId,
      thread.copyWith(
        comments: updatedComments,
        repliesByParent: updatedReplies,
      ),
    );

    try {
      await _repository.toggleCommentLike(
        commentId: commentId,
        userId: userId,
      );
    } catch (_) {
      // Revert on failure.
      _setThread(postId, thread);
    }
  }

  /// Load replies for a parent comment and stash them on the thread state.
  Future<void> loadReplies({
    required String postId,
    required String parentCommentId,
  }) async {
    final thread = state.threadFor(postId);
    if (thread.repliesByParent.containsKey(parentCommentId)) return;

    try {
      final raw = await _repository.fetchReplies(parentCommentId);
      final currentUserId = _currentUserId;
      final hydrated = currentUserId != null
          ? await _repository.hydrateMetadata(
              raw,
              currentUserId: currentUserId,
            )
          : raw;
      final updated =
          Map<String, List<CommentModel>>.from(thread.repliesByParent);
      updated[parentCommentId] = hydrated;
      _setThread(postId, thread.copyWith(repliesByParent: updated));
    } catch (_) {
      // ignore
    }
  }

  /// Hide previously loaded replies (collapse view).
  void collapseReplies({required String postId, required String parentCommentId}) {
    final thread = state.threadFor(postId);
    if (!thread.repliesByParent.containsKey(parentCommentId)) return;
    final updated =
        Map<String, List<CommentModel>>.from(thread.repliesByParent)
          ..remove(parentCommentId);
    _setThread(postId, thread.copyWith(repliesByParent: updated));
  }

  int _countAll(List<CommentModel> comments) {
    var total = 0;
    for (final c in comments) {
      total += 1 + c.replyCount;
    }
    return total;
  }

  /// The current user's id, used to hydrate isLikedByMe. Wired by the
  /// PostDetailScreen on mount.
  String? _currentUserId;
  void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final thread = state.threadFor(postId);
    final previousCount = state.countFor(postId);

    // Locate the comment — could be top-level or inside a reply bucket.
    CommentModel? topLevel;
    try {
      topLevel = thread.comments.firstWhere((c) => c.id == commentId);
    } catch (_) {}

    final updatedComments =
        thread.comments.where((c) => c.id != commentId).toList();
    final updatedReplies = <String, List<CommentModel>>{
      for (final entry in thread.repliesByParent.entries)
        entry.key: entry.value.where((c) => c.id != commentId).toList(),
    };

    // If it was a reply, also decrement the parent's replyCount.
    if (topLevel == null) {
      // It must have been a reply.
      final mutatedComments = updatedComments.map((c) {
        final hadReply = (thread.repliesByParent[c.id] ?? const [])
            .any((r) => r.id == commentId);
        return hadReply
            ? c.copyWith(replyCount: (c.replyCount - 1).clamp(0, 1 << 31))
            : c;
      }).toList();
      _setThread(
        postId,
        thread.copyWith(
          comments: mutatedComments,
          repliesByParent: updatedReplies,
          clearError: true,
        ),
      );
      _setCount(postId, (previousCount - 1).clamp(0, 1 << 31));
    } else {
      // Top-level removed — also accounts for its cascade-deleted replies.
      final delta = 1 + topLevel.replyCount;
      _setThread(
        postId,
        thread.copyWith(
          comments: updatedComments,
          repliesByParent: updatedReplies,
          clearError: true,
        ),
      );
      _setCount(postId, (previousCount - delta).clamp(0, 1 << 31));
    }

    try {
      await _repository.deleteComment(commentId);
    } catch (e) {
      // Revert on failure.
      _setThread(
        postId,
        thread.copyWith(errorMessage: e.toString()),
      );
      _setCount(postId, previousCount);
    }
  }

  void _ensureSubscription(String postId) {
    if (_channels.containsKey(postId)) return;
    _channels[postId] = _repository.subscribeToComments(
      postId: postId,
      onCommentAdded: (comment) {
        final thread = state.threadFor(postId);

        // Dedup: ignore if we've already seen this comment in the top-level
        // list or in any expanded reply bucket.
        final alreadyTopLevel =
            thread.comments.any((c) => c.id == comment.id);
        final alreadyInReplies = thread.repliesByParent.values
            .any((list) => list.any((c) => c.id == comment.id));
        if (alreadyTopLevel || alreadyInReplies) return;

        if (comment.parentCommentId == null) {
          // Top-level comment from another client.
          final next = [...thread.comments, comment];
          _setThread(postId, thread.copyWith(comments: next));
          _setCount(postId, state.countFor(postId) + 1);
        } else {
          // Reply: bump the parent's replyCount, and if the parent's reply
          // thread is currently expanded, append the reply into it. Do NOT
          // add it to the top-level list.
          final parentId = comment.parentCommentId!;
          final updatedComments = thread.comments
              .map(
                (c) => c.id == parentId
                    ? c.copyWith(replyCount: c.replyCount + 1)
                    : c,
              )
              .toList();
          final updatedReplies =
              Map<String, List<CommentModel>>.from(thread.repliesByParent);
          final existing = updatedReplies[parentId];
          if (existing != null) {
            updatedReplies[parentId] = [...existing, comment];
          }
          _setThread(
            postId,
            thread.copyWith(
              comments: updatedComments,
              repliesByParent: updatedReplies,
            ),
          );
          _setCount(postId, state.countFor(postId) + 1);
        }
      },
      onCommentDeleted: (commentId) {
        final thread = state.threadFor(postId);
        final next = thread.comments.where((c) => c.id != commentId).toList();
        final removedTopLevel = next.length != thread.comments.length;
        // Also strip from any expanded reply buckets.
        final updatedReplies = <String, List<CommentModel>>{
          for (final entry in thread.repliesByParent.entries)
            entry.key:
                entry.value.where((c) => c.id != commentId).toList(),
        };
        final repliesBefore = thread.repliesByParent.values
            .fold<int>(0, (a, b) => a + b.length);
        final repliesAfter = updatedReplies.values
            .fold<int>(0, (a, b) => a + b.length);
        final removedReplies = repliesBefore - repliesAfter;

        if (!removedTopLevel && removedReplies == 0) return;

        // If a top-level comment was removed, also decrement the count by
        // the replies it carried (they cascade-delete server-side).
        var delta = removedTopLevel ? 1 : 0;
        if (removedTopLevel) {
          final original =
              thread.comments.firstWhere((c) => c.id == commentId);
          delta += original.replyCount;
        }
        delta += removedReplies;

        _setThread(
          postId,
          thread.copyWith(
            comments: next,
            repliesByParent: updatedReplies,
          ),
        );
        _setCount(
          postId,
          (state.countFor(postId) - delta).clamp(0, 1 << 31),
        );
      },
    );
  }

  /// Stop the realtime subscription for a single post thread (e.g. when the
  /// comments screen for it pops). Optional — the controller cleans up
  /// everything on dispose.
  void unsubscribe(String postId) {
    final channel = _channels.remove(postId);
    if (channel == null) return;
    try {
      Supabase.instance.client.removeChannel(channel);
    } catch (_) {
      // Supabase not initialized.
    }
  }

  void _setThread(String postId, CommentThreadState thread) {
    final updated = Map<String, CommentThreadState>.from(state.threads);
    updated[postId] = thread;
    state = state.copyWith(threads: updated);
  }

  void _setCount(String postId, int count) {
    final updated = Map<String, int>.from(state.counts);
    updated[postId] = count;
    state = state.copyWith(counts: updated);
  }
}
