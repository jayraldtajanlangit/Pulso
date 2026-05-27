import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/like_providers.dart';
import 'like_repository.dart';

class LikeStatus {
  const LikeStatus({required this.isLiked, required this.count});

  const LikeStatus.empty() : isLiked = false, count = 0;

  final bool isLiked;
  final int count;

  LikeStatus copyWith({bool? isLiked, int? count}) =>
      LikeStatus(isLiked: isLiked ?? this.isLiked, count: count ?? this.count);
}

class LikeState {
  const LikeState({
    required this.statuses,
    this.errorMessage,
  });

  const LikeState.initial() : statuses = const {}, errorMessage = null;

  final Map<String, LikeStatus> statuses;
  final String? errorMessage;

  LikeStatus statusFor(String postId) =>
      statuses[postId] ?? const LikeStatus.empty();

  LikeState copyWith({
    Map<String, LikeStatus>? statuses,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LikeState(
      statuses: statuses ?? this.statuses,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class LikeController extends Notifier<LikeState> {
  RealtimeChannel? _channel;

  LikeRepository get _repository => ref.read(likeRepositoryProvider);

  @override
  LikeState build() {
    ref.onDispose(() {
      final channel = _channel;
      if (channel == null) return;
      try {
        Supabase.instance.client.removeChannel(channel);
      } catch (_) {
        // Supabase not initialized (e.g., during unit tests).
      }
      _channel = null;
    });
    return const LikeState.initial();
  }

  /// Subscribe to the realtime likes channel. Safe to call multiple times —
  /// existing subscription is replaced.
  void subscribe({required String currentUserId}) {
    if (_channel != null) return;
    _channel = _repository.subscribeToLikes(
      onLikeChanged: (postId) => _refreshPost(postId, currentUserId),
    );
  }

  /// Load counts and current user's like state for a batch of posts.
  Future<void> loadForPosts({
    required List<String> postIds,
    required String currentUserId,
  }) async {
    if (postIds.isEmpty) return;
    try {
      final counts = await _repository.getLikeCountsForPosts(postIds);
      final liked = await _repository.getLikedPostIdsForUser(
        userId: currentUserId,
        postIds: postIds,
      );

      final updated = Map<String, LikeStatus>.from(state.statuses);
      for (final id in postIds) {
        updated[id] = LikeStatus(
          isLiked: liked.contains(id),
          count: counts[id] ?? 0,
        );
      }
      state = state.copyWith(statuses: updated, clearError: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Load fresh status for a single post.
  Future<void> loadForPost({
    required String postId,
    required String currentUserId,
  }) {
    return loadForPosts(postIds: [postId], currentUserId: currentUserId);
  }

  /// Toggle the like for the current user. Optimistically updates the UI,
  /// reconciles with the server response.
  Future<void> toggle({
    required String postId,
    required String currentUserId,
  }) async {
    final current = state.statusFor(postId);
    // Optimistic update.
    final optimistic = LikeStatus(
      isLiked: !current.isLiked,
      count: (current.count + (current.isLiked ? -1 : 1)).clamp(0, 1 << 31),
    );
    _setStatus(postId, optimistic);

    try {
      final nowLiked = await _repository.toggleLike(
        postId: postId,
        userId: currentUserId,
      );
      // Reconcile if the optimistic guess was wrong (e.g. duplicate hit).
      if (nowLiked != optimistic.isLiked) {
        await _refreshPost(postId, currentUserId);
      }
    } catch (e) {
      // Revert on failure.
      _setStatus(postId, current);
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> _refreshPost(String postId, String currentUserId) async {
    try {
      final count = await _repository.getLikeCount(postId);
      final isLiked = await _repository.isLikedByUser(
        postId: postId,
        userId: currentUserId,
      );
      _setStatus(postId, LikeStatus(isLiked: isLiked, count: count));
    } catch (_) {
      // Silently ignore — UI will retry on next interaction.
    }
  }

  void _setStatus(String postId, LikeStatus status) {
    final updated = Map<String, LikeStatus>.from(state.statuses);
    updated[postId] = status;
    state = state.copyWith(statuses: updated, clearError: true);
  }
}
