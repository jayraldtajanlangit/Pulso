import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/follow_providers.dart';
import '../providers/notification_providers.dart';
import 'follow_repository.dart';

class FollowStats {
  const FollowStats({required this.followers, required this.following});

  const FollowStats.zero() : followers = 0, following = 0;

  final int followers;
  final int following;

  FollowStats copyWith({int? followers, int? following}) =>
      FollowStats(
        followers: followers ?? this.followers,
        following: following ?? this.following,
      );
}

class FollowState {
  const FollowState({
    required this.followingByCurrentUser,
    required this.stats,
    this.errorMessage,
    this.pendingTargetIds = const {},
  });

  const FollowState.initial()
    : followingByCurrentUser = const {},
      stats = const {},
      errorMessage = null,
      pendingTargetIds = const {};

  /// Set of userIds the current user is following (cache).
  final Set<String> followingByCurrentUser;

  /// Stats keyed by the userId the stats describe.
  final Map<String, FollowStats> stats;

  final String? errorMessage;

  /// Target user ids whose follow toggle is currently in flight.
  final Set<String> pendingTargetIds;

  bool isFollowing(String userId) => followingByCurrentUser.contains(userId);

  bool isPending(String userId) => pendingTargetIds.contains(userId);

  FollowStats statsFor(String userId) =>
      stats[userId] ?? const FollowStats.zero();

  FollowState copyWith({
    Set<String>? followingByCurrentUser,
    Map<String, FollowStats>? stats,
    String? errorMessage,
    Set<String>? pendingTargetIds,
    bool clearError = false,
  }) {
    return FollowState(
      followingByCurrentUser:
          followingByCurrentUser ?? this.followingByCurrentUser,
      stats: stats ?? this.stats,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      pendingTargetIds: pendingTargetIds ?? this.pendingTargetIds,
    );
  }
}

class FollowController extends Notifier<FollowState> {
  FollowRepository get _repository => ref.read(followRepositoryProvider);

  @override
  FollowState build() => const FollowState.initial();

  /// Refresh stats (followers + following counts) for a target user.
  Future<void> loadStats(String userId) async {
    try {
      final followers = await _repository.getFollowerCount(userId);
      final following = await _repository.getFollowingCount(userId);
      final updated = Map<String, FollowStats>.from(state.stats);
      updated[userId] =
          FollowStats(followers: followers, following: following);
      state = state.copyWith(stats: updated, clearError: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Load the current user's follow state for a given target user.
  Future<void> loadFollowState({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return;
    try {
      final isFollowing = await _repository.isFollowing(
        followerId: currentUserId,
        followingId: targetUserId,
      );
      final updated =
          Set<String>.from(state.followingByCurrentUser);
      if (isFollowing) {
        updated.add(targetUserId);
      } else {
        updated.remove(targetUserId);
      }
      state = state.copyWith(
        followingByCurrentUser: updated,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Bulk-load the follow set for the current user (used by feed filters).
  Future<void> loadFollowingIds(String currentUserId) async {
    try {
      final ids = await _repository.getFollowingIds(currentUserId);
      state = state.copyWith(
        followingByCurrentUser: ids.toSet(),
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> toggleFollow({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return;
    if (state.isPending(targetUserId)) return;

    final wasFollowing = state.isFollowing(targetUserId);
    final updatedSet = Set<String>.from(state.followingByCurrentUser);
    if (wasFollowing) {
      updatedSet.remove(targetUserId);
    } else {
      updatedSet.add(targetUserId);
    }

    final updatedStats = Map<String, FollowStats>.from(state.stats);
    final currentStats = updatedStats[targetUserId] ?? const FollowStats.zero();
    updatedStats[targetUserId] = currentStats.copyWith(
      followers: (currentStats.followers + (wasFollowing ? -1 : 1))
          .clamp(0, 1 << 31),
    );
    final myStats = updatedStats[currentUserId] ?? const FollowStats.zero();
    updatedStats[currentUserId] = myStats.copyWith(
      following: (myStats.following + (wasFollowing ? -1 : 1))
          .clamp(0, 1 << 31),
    );

    state = state.copyWith(
      followingByCurrentUser: updatedSet,
      stats: updatedStats,
      pendingTargetIds: {...state.pendingTargetIds, targetUserId},
      clearError: true,
    );

    try {
      final nowFollowing = await _repository.toggleFollow(
        followerId: currentUserId,
        followingId: targetUserId,
      );
      if (nowFollowing != !wasFollowing) {
        // Reconcile if server disagreed with our optimistic guess.
        await loadFollowState(
          currentUserId: currentUserId,
          targetUserId: targetUserId,
        );
        await loadStats(targetUserId);
      }
      await loadStats(currentUserId);
      if (nowFollowing) {
        try {
          await ref.read(notificationRepositoryProvider).insertNotification(
            recipientId: targetUserId,
            actorId: currentUserId,
            type: 'follow',
          );
        } catch (_) {}
      }
    } catch (e) {
      // Revert.
      state = state.copyWith(
        followingByCurrentUser: state.followingByCurrentUser
            .where((id) => id != targetUserId)
            .toSet()
          ..addAll(wasFollowing ? {targetUserId} : <String>{}),
        stats: {
          ...state.stats,
          targetUserId: currentStats,
        },
        errorMessage: e.toString(),
      );
    } finally {
      final pending = Set<String>.from(state.pendingTargetIds)
        ..remove(targetUserId);
      state = state.copyWith(pendingTargetIds: pending);
    }
  }
}
