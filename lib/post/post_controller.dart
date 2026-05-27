import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/post_providers.dart';
import '../providers/services_providers.dart';
import '../services/image_picker_service.dart';
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
    required this.pendingImages,
    this.errorMessage,
    this.postCreated = false,
  });

  PostState.initial()
    : isLoading = false,
      isLoadingMore = false,
      isCreating = false,
      hasMore = true,
      posts = const [],
      pendingImages = const [],
      errorMessage = null,
      postCreated = false;

  final bool isLoading;
  final bool isLoadingMore;
  final bool isCreating;
  final bool hasMore;
  final List<PostModel> posts;
  final List<PickedImage> pendingImages;
  final String? errorMessage;

  /// Flipped to true on successful creation so the screen can pop.
  final bool postCreated;

  // Convenience getter for backward-compat UI checks.
  Uint8List? get pendingImageBytes =>
      pendingImages.isNotEmpty ? pendingImages.first.bytes : null;

  PostState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isCreating,
    bool? hasMore,
    List<PostModel>? posts,
    List<PickedImage>? pendingImages,
    String? errorMessage,
    bool? postCreated,
    bool clearPendingImages = false,
    bool clearError = false,
  }) {
    return PostState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isCreating: isCreating ?? this.isCreating,
      hasMore: hasMore ?? this.hasMore,
      posts: posts ?? this.posts,
      pendingImages: clearPendingImages
          ? const []
          : pendingImages ?? this.pendingImages,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      postCreated: postCreated ?? this.postCreated,
    );
  }
}

class PostController extends Notifier<PostState> {
  @override
  PostState build() => PostState.initial();

  PostRepository get _repository => ref.read(postRepositoryProvider);

  /// Load posts for a single user (used on profile screens).
  Future<void> loadPosts(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final posts = await _repository.getPosts(userId);
      state = state.copyWith(isLoading: false, posts: posts, hasMore: false);
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
      final posts = await _repository.fetchFeed(limit: limit, offset: 0);
      state = state.copyWith(
        isLoading: false,
        posts: posts,
        hasMore: posts.length >= limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Reset and load the first page of the following-only feed.
  Future<void> loadFollowingFeed({
    required List<String> followingIds,
    int limit = kFeedPageSize,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      posts: const [],
      hasMore: true,
    );
    try {
      final posts = await _repository.fetchFollowingFeed(
        followingIds: followingIds,
        limit: limit,
        offset: 0,
      );
      state = state.copyWith(
        isLoading: false,
        posts: posts,
        hasMore: posts.length >= limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Append the next page of the following-only feed (infinite scroll).
  Future<void> loadMoreFollowingFeed({
    required List<String> followingIds,
    int limit = kFeedPageSize,
  }) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final more = await _repository.fetchFollowingFeed(
        followingIds: followingIds,
        limit: limit,
        offset: state.posts.length,
      );
      final existingIds = state.posts.map((p) => p.id).toSet();
      final additions = more.where((p) => !existingIds.contains(p.id)).toList();
      state = state.copyWith(
        isLoadingMore: false,
        posts: [...state.posts, ...additions],
        hasMore: more.length >= limit,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, errorMessage: e.toString());
    }
  }

  /// Append the next page of the feed (infinite scroll).
  Future<void> loadMoreFeed({int limit = kFeedPageSize}) async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final more = await _repository.fetchFeed(
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
      state = state.copyWith(isLoadingMore: false, errorMessage: e.toString());
    }
  }

  Future<void> addImages() async {
    final picked = await ref
        .read(imagePickerServiceProvider)
        .pickMultipleImages();
    if (picked.isNotEmpty) {
      state = state.copyWith(
        pendingImages: [...state.pendingImages, ...picked],
      );
    }
  }

  void removeImage(int index) {
    final updated = List<PickedImage>.from(state.pendingImages)
      ..removeAt(index);
    state = state.copyWith(pendingImages: updated);
  }

  void clearPendingImages() {
    state = state.copyWith(clearPendingImages: true);
  }

  // Keep old name as alias so existing call-sites don't break.
  void clearPendingImage() => clearPendingImages();

  Future<void> editPost(String postId, {required String caption}) async {
    try {
      final updated = await _repository.updatePost(
        postId,
        caption: caption.trim(),
      );
      state = state.copyWith(
        posts: state.posts.map((p) => p.id == postId ? updated : p).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _repository.deletePost(postId);
      state = state.copyWith(
        posts: state.posts.where((p) => p.id != postId).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> pickImage() async {
    final picked = await ref.read(imagePickerServiceProvider).pickImage();
    if (picked != null) {
      state = state.copyWith(pendingImages: [...state.pendingImages, picked]);
    }
  }

  Future<void> createPost({
    required String userId,
    required String caption,
  }) async {
    final trimmed = caption.trim();
    if (state.pendingImages.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please choose an image for your post.',
      );
      return;
    }

    state = state.copyWith(
      isCreating: true,
      clearError: true,
      postCreated: false,
    );
    try {
      final urls = await _repository.uploadPostImages(
        userId,
        state.pendingImages,
      );

      final post = PostModel(
        id: '',
        userId: userId,
        caption: trimmed,
        imageUrl: urls.first,
        imageUrls: urls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final created = await _repository.createPost(
        post,
        extraImageUrls: urls.skip(1).toList(),
      );
      state = state.copyWith(
        isCreating: false,
        posts: [created, ...state.posts],
        clearPendingImages: true,
        postCreated: true,
      );
    } catch (e) {
      state = state.copyWith(isCreating: false, errorMessage: e.toString());
    }
  }
}
