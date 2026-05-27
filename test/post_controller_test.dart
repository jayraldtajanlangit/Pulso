import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/post/post_repository.dart';
import 'package:pulso/providers/post_providers.dart';
import 'package:pulso/providers/services_providers.dart';
import 'package:pulso/services/image_picker_service.dart';

void main() {
  group('PostController', () {
    test('starts in initial state with empty posts list', () {
      final container = ProviderContainer.test(
        overrides: [
          postRepositoryProvider.overrideWithValue(FakePostRepository()),
          imagePickerServiceProvider.overrideWithValue(
            FakeImagePickerService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(postControllerProvider);

      expect(state.isLoading, isFalse);
      expect(state.isCreating, isFalse);
      expect(state.posts, isEmpty);
      expect(state.errorMessage, isNull);
      expect(state.postCreated, isFalse);
    });

    test('rejects empty content without calling repository', () async {
      final repo = FakePostRepository();
      final container = ProviderContainer.test(
        overrides: [
          postRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(
            FakeImagePickerService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(postControllerProvider.notifier).createPost(
        userId: 'user-1',
        content: '   ',
      );

      expect(repo.createPostCalled, isFalse);
      expect(
        container.read(postControllerProvider).errorMessage,
        'Post content cannot be empty.',
      );
    });

    test('createPost without image creates post and sets postCreated', () async {
      final repo = FakePostRepository();
      final container = ProviderContainer.test(
        overrides: [
          postRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(
            FakeImagePickerService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(postControllerProvider.notifier).createPost(
        userId: 'user-1',
        content: 'Hello world',
      );

      final state = container.read(postControllerProvider);
      expect(state.isCreating, isFalse);
      expect(state.postCreated, isTrue);
      expect(state.posts.length, 1);
      expect(state.posts.first.content, 'Hello world');
      expect(state.posts.first.imageUrl, isNull);
    });

    test('createPost uploads pending image before creating post', () async {
      final repo = FakePostRepository();
      final picker = FakeImagePickerService(
        result: (bytes: Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg'),
      );
      final container = ProviderContainer.test(
        overrides: [
          postRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(picker),
        ],
      );
      addTearDown(container.dispose);

      // Pick an image first.
      await container.read(postControllerProvider.notifier).pickImage();
      expect(
        container.read(postControllerProvider).pendingImageBytes,
        isNotNull,
      );

      // Create post – should upload image and attach URL.
      await container.read(postControllerProvider.notifier).createPost(
        userId: 'user-1',
        content: 'Post with image',
      );

      final state = container.read(postControllerProvider);
      expect(state.postCreated, isTrue);
      expect(state.posts.first.imageUrl, isNotNull);
      expect(state.pendingImageBytes, isNull); // cleared after creation
      expect(repo.uploadPostImageCalled, isTrue);
    });

    test('loadPosts fetches posts for user', () async {
      final repo = FakePostRepository(
        seedPosts: [
          PostModel(
            id: 'p1',
            userId: 'user-1',
            content: 'Seeded post',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ],
      );
      final container = ProviderContainer.test(
        overrides: [
          postRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(
            FakeImagePickerService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(postControllerProvider.notifier)
          .loadPosts('user-1');

      final state = container.read(postControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.posts.length, 1);
      expect(state.posts.first.content, 'Seeded post');
    });

    test('clearPendingImage removes pending bytes', () async {
      final picker = FakeImagePickerService(
        result: (bytes: Uint8List.fromList([9, 8, 7]), mimeType: 'image/png'),
      );
      final container = ProviderContainer.test(
        overrides: [
          postRepositoryProvider.overrideWithValue(FakePostRepository()),
          imagePickerServiceProvider.overrideWithValue(picker),
        ],
      );
      addTearDown(container.dispose);

      await container.read(postControllerProvider.notifier).pickImage();
      expect(
        container.read(postControllerProvider).pendingImageBytes,
        isNotNull,
      );

      container.read(postControllerProvider.notifier).clearPendingImage();
      expect(
        container.read(postControllerProvider).pendingImageBytes,
        isNull,
      );
    });
  });
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class FakePostRepository implements PostRepository {
  FakePostRepository({List<PostModel>? seedPosts})
    : _posts = List<PostModel>.from(seedPosts ?? []);

  final List<PostModel> _posts;
  bool createPostCalled = false;
  bool uploadPostImageCalled = false;

  @override
  Future<List<PostModel>> getPosts(String userId) async =>
      _posts.where((p) => p.userId == userId).toList();

  @override
  Future<List<PostModel>> getFeed({int limit = 20, int offset = 0}) async =>
      List<PostModel>.from(_posts);

  @override
  Future<void> deletePost(String postId) async {
    _posts.removeWhere((p) => p.id == postId);
  }

  @override
  Future<PostModel> createPost(PostModel post) async {
    createPostCalled = true;
    final created = PostModel(
      id: 'new-id',
      userId: post.userId,
      content: post.content,
      imageUrl: post.imageUrl,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    _posts.add(created);
    return created;
  }

  @override
  Future<String> uploadPostImage(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async {
    uploadPostImageCalled = true;
    return 'https://example.com/$userId/post.jpg';
  }
}

class FakeImagePickerService implements ImagePickerService {
  FakeImagePickerService({this.result});

  final PickedImage? result;

  @override
  Future<PickedImage?> pickImage() async => result;
}
