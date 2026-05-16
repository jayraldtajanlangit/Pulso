import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/post_providers.dart';
import '../providers/services_providers.dart';
import 'post_model.dart';
import 'post_repository.dart';

class PostState {
  const PostState({
    required this.isLoading,
    required this.isCreating,
    required this.posts,
    this.pendingImageBytes,
    this.errorMessage,
    this.postCreated = false,
  });

  const PostState.initial()
    : isLoading = false,
      isCreating = false,
      posts = const [],
      pendingImageBytes = null,
      errorMessage = null,
      postCreated = false;

  final bool isLoading;
  final bool isCreating;
  final List<PostModel> posts;
  final Uint8List? pendingImageBytes;
  final String? errorMessage;

  /// Flipped to true on successful creation so the screen can pop.
  final bool postCreated;

  PostState copyWith({
    bool? isLoading,
    bool? isCreating,
    List<PostModel>? posts,
    Uint8List? pendingImageBytes,
    String? errorMessage,
    bool? postCreated,
    bool clearPendingImage = false,
    bool clearError = false,
  }) {
    return PostState(
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
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

  Future<void> loadPosts(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final posts = await _repository.getPosts(userId);
      state = state.copyWith(isLoading: false, posts: posts);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(errorMessage: 'Post content cannot be empty.');
      return;
    }

    state = state.copyWith(
      isCreating: true,
      clearError: true,
      postCreated: false,
    );
    try {
      String? imageUrl;
      final bytes = state.pendingImageBytes;
      if (bytes != null) {
        imageUrl = await _repository.uploadPostImage(userId, bytes, 'image/jpeg');
      }

      final post = PostModel(
        id: '',
        userId: userId,
        content: trimmed,
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
