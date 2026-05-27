import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/post_providers.dart';
import '../providers/services_providers.dart';
import 'post_model.dart';
import 'post_repository.dart';

const int kFeedPageSize = 10;

class PostState {
  const PostState({
    required this.isLoading,
    required this.isLoadingMore,
    required this.isCreating,
    required this.hasMore,
    required this.posts,
    this.pendingImageBytes,
    this.errorMessage,
    this.postCreated = false,
  });

  const PostState.initial()
    : isLoading = false,
      isLoadingMore = false,
      isCreating = false,
      hasMore = true,
      posts = const [],
      pendingImageBytes = null,
      errorMessage = null,
      postCreated = false;

  final bool isLoading;
  final bool isLoadingMore;
  final bool isCreating;
  final bool hasMore;
  final List<PostModel> posts;
  final Uint8List? pendingImageBytes;
  final String? errorMessage;

  /// Flipped to true on successful creation so the screen can pop.
  final bool postCreated;

  PostState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isCreating,
    bool? hasMore,
    List<PostModel>? posts,
    Uint8List? pendingImageBytes,
    String? errorMessage,
    bool? postCreated,
    bool clearPendingImage = false,
    bool clearError = false,
  }) {
    return PostState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isCreating: isCreating ?? this.isCreating,
      hasMore: hasMore ?? this.hasMore,
      posts: posts ?? this.posts,
      pendingImageBytes:
          clearPendingImage ? null : pendingImageBytes ?? this.pendingImageBytes,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      postCreated: postCreated ?? this.postCreated,
    );
  }
}

class PostController extends Notifier<PostState> {
  @override
  PostState build() => const PostState.initial();

  PostRepository get _repository => ref.read(postRepositoryProvider);

  /// Load posts for a single user (used on profile screens).
  Future<void> loadPosts(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final posts = await _repository.getPosts(userId);
      state = state.copyWith(
        isLoading: false,
        posts: posts,
        hasMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Reset and load the first page of the global feed.
  Future<void> loadFeed({int limit = kFeedPageSize}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      posts: const [],
      hasMore: true,
    );
    try {
      final posts = await _repository.getFeed(limit: limit, offset: 0);
      state = state.copyWith(
        isLoading: false,
        posts: posts,
        hasMore: posts.length >= limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Append the next page of the feed (infinite scroll).
  Future<void> loadMoreFeed({int limit = kFeedPageSize}) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final more = await _repository.getFeed(
        limit: limit,
        offset: state.posts.length,
      );
      // De-dupe in case the realtime layer already inserted some.
      final existingIds = state.posts.map((p) => p.id).toSet();
      final additions = more.where((p) => !existingIds.contains(p.id)).toList();
      state = state.copyWith(
        isLoadingMore: false,
        posts: [...state.posts, ...additions],
        hasMore: more.length >= limit,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> pickImage() async {
    final picked = await ref.read(imagePickerServiceProvider).pickImage();
    if (picked != null) {
      state = state.copyWith(pendingImageBytes: picked.bytes);
    }
  }

  void clearPendingImage() {
    state = state.copyWith(clearPendingImage: true);
  }

  Future<void> createPost({
    required String userId,
    required String caption,
  }) async {
    final trimmed = caption.trim();
    final bytes = state.pendingImageBytes;
    if (bytes == null) {
      state = state.copyWith(errorMessage: 'Please choose an image for your post.');
      return;
    }

    state = state.copyWith(
      isCreating: true,
      clearError: true,
      postCreated: false,
    );
    try {
      final imageUrl =
          await _repository.uploadPostImage(userId, bytes, 'image/jpeg');

      final post = PostModel(
        id: '',
        userId: userId,
        caption: trimmed,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final created = await _repository.createPost(post);
      state = state.copyWith(
        isCreating: false,
        posts: [created, ...state.posts],
        clearPendingImage: true,
        postCreated: true,
      );
    } catch (e) {
      state = state.copyWith(isCreating: false, errorMessage: e.toString());
    }
  }
}
