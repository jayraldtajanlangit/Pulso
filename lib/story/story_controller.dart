import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}
