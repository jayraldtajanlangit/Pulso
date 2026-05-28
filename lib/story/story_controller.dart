import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_providers.dart';
import '../providers/story_providers.dart';
import 'music_clip_model.dart';
import 'story_model.dart';
import 'story_repository.dart';

class StoryState {
  const StoryState({
    required this.storiesByUser,
    required this.musicClips,
    this.isLoading = false,
    this.isPosting = false,
  });

  const StoryState.initial()
      : storiesByUser = const {},
        musicClips = const [],
        isLoading = false,
        isPosting = false;

  /// Ordered map: current user first, then followed users.
  final Map<String, List<StoryModel>> storiesByUser;
  final List<MusicClipModel> musicClips;
  final bool isLoading;
  final bool isPosting;

  StoryState copyWith({
    Map<String, List<StoryModel>>? storiesByUser,
    List<MusicClipModel>? musicClips,
    bool? isLoading,
    bool? isPosting,
  }) {
    return StoryState(
      storiesByUser: storiesByUser ?? this.storiesByUser,
      musicClips: musicClips ?? this.musicClips,
      isLoading: isLoading ?? this.isLoading,
      isPosting: isPosting ?? this.isPosting,
    );
  }
}

class StoryController extends Notifier<StoryState> {
  StoryRepository get _repository => ref.read(storyRepositoryProvider);

  @override
  StoryState build() => const StoryState.initial();

  Future<void> loadActiveStories({
    required List<String> followingIds,
    required String currentUserId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final storiesByUser = await _repository.fetchActiveStories(
        followingIds: followingIds,
        currentUserId: currentUserId,
      );
      state = state.copyWith(storiesByUser: storiesByUser, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMusicClips() async {
    if (state.musicClips.isNotEmpty) return;
    try {
      final clips = await _repository.fetchMusicClips();
      state = state.copyWith(musicClips: clips);
    } catch (_) {}
  }

  Future<void> recordView({
    required String storyId,
    required String viewerId,
  }) async {
    try {
      await _repository.recordView(storyId: storyId, viewerId: viewerId);
      final updated = <String, List<StoryModel>>{};
      for (final entry in state.storiesByUser.entries) {
        updated[entry.key] = entry.value
            .map((s) =>
                s.id == storyId ? s.copyWith(viewedByCurrentUser: true) : s)
            .toList();
      }
      state = state.copyWith(storiesByUser: updated);
    } catch (_) {}
  }

  Future<void> createStory({
    required String userId,
    required File imageFile,
    String? musicClipId,
  }) async {
    state = state.copyWith(isPosting: true);
    try {
      final story = await _repository.createStory(
        userId: userId,
        imageFile: imageFile,
        musicClipId: musicClipId,
      );
      final updated = Map<String, List<StoryModel>>.from(state.storiesByUser);
      updated[userId] = [story, ...(updated[userId] ?? [])];
      state = state.copyWith(storiesByUser: updated, isPosting: false);
    } catch (_) {
      state = state.copyWith(isPosting: false);
    }
  }

  /// Toggle the current user's heart reaction on [storyId]. Updates the
  /// local state optimistically, reconciles with the server, and fires a
  /// notification to the story owner on a fresh react (never on un-react,
  /// never to yourself).
  Future<void> toggleReaction({
    required String storyId,
    required String currentUserId,
    required String storyOwnerId,
  }) async {
    // Locate the story to flip in state.
    StoryModel? current;
    for (final list in state.storiesByUser.values) {
      for (final s in list) {
        if (s.id == storyId) {
          current = s;
          break;
        }
      }
      if (current != null) break;
    }
    if (current == null) return;

    final wasLiked = current.isLikedByMe;
    _setIsLiked(storyId, !wasLiked);

    try {
      final nowLiked = await _repository.toggleReaction(
        storyId: storyId,
        userId: currentUserId,
      );
      // Reconcile with server if it disagrees with our optimistic guess.
      if (nowLiked != !wasLiked) {
        _setIsLiked(storyId, nowLiked);
      }
      // Notify the owner on a fresh react (not when un-reacting, not on self).
      if (nowLiked && storyOwnerId != currentUserId) {
        try {
          await ref.read(notificationRepositoryProvider).insertNotification(
                recipientId: storyOwnerId,
                actorId: currentUserId,
                type: 'story_like',
                storyId: storyId,
              );
        } catch (_) {
          // Notification insertion is best-effort.
        }
      }
    } catch (_) {
      // Revert on failure.
      _setIsLiked(storyId, wasLiked);
    }
  }

  void _setIsLiked(String storyId, bool isLiked) {
    final updated = <String, List<StoryModel>>{};
    for (final entry in state.storiesByUser.entries) {
      updated[entry.key] = entry.value
          .map((s) => s.id == storyId ? s.copyWith(isLikedByMe: isLiked) : s)
          .toList();
    }
    state = state.copyWith(storiesByUser: updated);
  }
}
