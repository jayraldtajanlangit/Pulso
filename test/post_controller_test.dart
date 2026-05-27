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

    test('rejects createPost when no image has been picked', () async {
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
        caption: 'no image',
      );

      expect(repo.createPostCalled, isFalse);
      expect(
        container.read(postControllerProvider).errorMessage,
        'Please choose an image for your post.',
      );
    });

    test('createPost uploads pending image and creates the post', () async {
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

      await container.read(postControllerProvider.notifier).pickImage();
      expect(
        container.read(postControllerProvider).pendingImageBytes,
        isNotNull,
      );

      await container.read(postControllerProvider.notifier).createPost(
        userId: 'user-1',
        caption: 'Post with image',
      );

      final state = container.read(postControllerProvider);
      expect(state.postCreated, isTrue);
      expect(state.posts.first.caption, 'Post with image');
      expect(state.posts.first.imageUrl, isNotEmpty);
      expect(state.pendingImageBytes, isNull); // cleared after creation
      expect(repo.uploadPostImageCalled, isTrue);
    });

    test('createPost allows an empty caption when an image is present',
        () async {
      final repo = FakePostRepository();
      final picker = FakeImagePickerService(
        result: (bytes: Uint8List.fromList([4, 5, 6]), mimeType: 'image/jpeg'),
      );
      final container = ProviderContainer.test(
        overrides: [
          postRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(picker),
        ],
      );
      addTearDown(container.dispose);

      await container.read(postControllerProvider.notifier).pickImage();
      await container.read(postControllerProvider.notifier).createPost(
        userId: 'user-1',
        caption: '   ',
      );

      final state = container.read(postControllerProvider);
      expect(state.postCreated, isTrue);
      expect(state.posts.first.caption, '');
    });

    test('loadPosts fetches posts for user', () async {
      final repo = FakePostRepository(
        seedPosts: [
          PostModel(
            id: 'p1',
            userId: 'user-1',
            caption: 'Seeded post',
            imageUrl: 'https://example.com/p1.jpg',
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
      expect(state.posts.first.caption, 'Seeded post');
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
  Future<List<PostModel>> fetchFeed({int limit = 20, int offset = 0}) async =>
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
      caption: post.caption,
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
