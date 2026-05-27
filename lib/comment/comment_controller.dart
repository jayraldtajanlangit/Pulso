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
    this.errorMessage,
  });

  const CommentThreadState.initial()
    : isLoading = false,
      isSubmitting = false,
      comments = const [],
      errorMessage = null;

  final bool isLoading;
  final bool isSubmitting;
  final List<CommentModel> comments;
  final String? errorMessage;

  CommentThreadState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<CommentModel>? comments,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CommentThreadState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      comments: comments ?? this.comments,
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

  CommentRepository get _repository => ref.read(commentRepositoryProvider);

  @override
  CommentState build() {
    ref.onDispose(() {
      if (_channels.isEmpty) return;
      try {
        final client = Supabase.instance.client;
        for (final channel in _channels.values) {
          client.removeChannel(channel);
        }
      } catch (_) {
        // Supabase not initialized (e.g., during unit tests).
      }
      _channels.clear();
    });
    return const CommentState.initial();
  }

  /// Load comments for a single post and start a realtime subscription.
  Future<void> loadComments(String postId) async {
    _setThread(
      postId,
      state.threadFor(postId).copyWith(isLoading: true, clearError: true),
    );
    try {
      final comments = await _repository.fetchComments(postId);
      _setThread(
        postId,
        CommentThreadState(
          isLoading: false,
          isSubmitting: false,
          comments: comments,
        ),
      );
      _setCount(postId, comments.length);
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
      );
      final thread = state.threadFor(postId);
      final hasIt = thread.comments.any((c) => c.id == created.id);
      final next = hasIt ? thread.comments : [...thread.comments, created];
      _setThread(
        postId,
        thread.copyWith(isSubmitting: false, comments: next),
      );
      _setCount(postId, next.length);
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

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final thread = state.threadFor(postId);
    final previous = thread.comments;
    final updated = previous.where((c) => c.id != commentId).toList();
    _setThread(postId, thread.copyWith(comments: updated, clearError: true));
    _setCount(postId, updated.length);

    try {
      await _repository.deleteComment(commentId);
    } catch (e) {
      // Revert on failure.
      _setThread(
        postId,
        thread.copyWith(comments: previous, errorMessage: e.toString()),
      );
      _setCount(postId, previous.length);
    }
  }

  void _ensureSubscription(String postId) {
    if (_channels.containsKey(postId)) return;
    _channels[postId] = _repository.subscribeToComments(
      postId: postId,
      onCommentAdded: (comment) {
        final thread = state.threadFor(postId);
        if (thread.comments.any((c) => c.id == comment.id)) return;
        final next = [...thread.comments, comment];
        _setThread(postId, thread.copyWith(comments: next));
        _setCount(postId, next.length);
      },
      onCommentDeleted: (commentId) {
        final thread = state.threadFor(postId);
        final next = thread.comments.where((c) => c.id != commentId).toList();
        if (next.length == thread.comments.length) return;
        _setThread(postId, thread.copyWith(comments: next));
        _setCount(postId, next.length);
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
