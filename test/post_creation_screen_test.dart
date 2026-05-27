import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/post/post_repository.dart';
import 'package:pulso/providers/post_providers.dart';
import 'package:pulso/providers/services_providers.dart';
import 'package:pulso/screens/post_creation_screen.dart';
import 'package:pulso/services/image_picker_service.dart';

void main() {
  Widget buildScreen({
    required String userId,
    FakePostRepository? repo,
    FakeImagePickerService? picker,
  }) {
    final container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(
          repo ?? FakePostRepository(),
        ),
        imagePickerServiceProvider.overrideWithValue(
          picker ?? FakeImagePickerService(),
        ),
      ],
    );

    addTearDown(container.dispose);

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PostCreationScreen(userId: userId)),
    );
  }

  testWidgets('shows content field, add photo button, and submit button',
      (tester) async {
    await tester.pumpWidget(buildScreen(userId: 'user-1'));
    await tester.pump();

    expect(find.byKey(const Key('postContentField')), findsOneWidget);
    expect(find.byKey(const Key('addImageButton')), findsOneWidget);
    expect(find.byKey(const Key('submitPostButton')), findsOneWidget);
  });

  testWidgets('shows error when submitting without an image', (tester) async {
    await tester.pumpWidget(buildScreen(userId: 'user-1'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('postContentField')),
      'Caption without image',
    );
    await tester.tap(find.byKey(const Key('submitPostButton')));
    await tester.pump();

    expect(find.byKey(const Key('postErrorMessage')), findsOneWidget);
    expect(
      find.text('Please choose an image for your post.'),
      findsOneWidget,
    );
  });

  testWidgets('shows image preview after picking an image', (tester) async {
    final picker = FakeImagePickerService(
      result: (
        bytes: Uint8List.fromList(
          // Minimal valid 1x1 white PNG bytes
          [
            137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0,
            0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0,
            12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 0, 0, 0, 2, 0, 1,
            226, 33, 188, 51, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
          ],
        ),
        mimeType: 'image/png',
      ),
    );

    await tester.pumpWidget(buildScreen(userId: 'user-1', picker: picker));
    await tester.pump();

    await tester.tap(find.byKey(const Key('addImageButton')));
    await tester.pump();

    expect(find.byKey(const Key('postImagePreview')), findsOneWidget);
    expect(find.byKey(const Key('removeImageButton')), findsOneWidget);
    // Add photo button is replaced by preview.
    expect(find.byKey(const Key('addImageButton')), findsNothing);
  });

  testWidgets('remove image button clears the preview', (tester) async {
    final picker = FakeImagePickerService(
      result: (
        bytes: Uint8List.fromList(
          // Minimal valid 1x1 white PNG bytes.
          [
            137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0,
            0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0,
            12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 0, 0, 0, 2, 0, 1,
            226, 33, 188, 51, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
          ],
        ),
        mimeType: 'image/png',
      ),
    );

    await tester.pumpWidget(buildScreen(userId: 'user-1', picker: picker));
    await tester.pump();

    await tester.tap(find.byKey(const Key('addImageButton')));
    await tester.pump();

    expect(find.byKey(const Key('postImagePreview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('removeImageButton')));
    await tester.pump();

    expect(find.byKey(const Key('postImagePreview')), findsNothing);
    expect(find.byKey(const Key('addImageButton')), findsOneWidget);
  });

  testWidgets('successful post creation calls repository', (tester) async {
    final repo = FakePostRepository();
    final picker = FakeImagePickerService(
      result: (
        bytes: Uint8List.fromList(
          [
            137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0,
            0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0,
            12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 0, 0, 0, 2, 0, 1,
            226, 33, 188, 51, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
          ],
        ),
        mimeType: 'image/png',
      ),
    );

    await tester.pumpWidget(
      buildScreen(userId: 'user-1', repo: repo, picker: picker),
    );
    await tester.pump();

    // Pick an image first (now required).
    await tester.tap(find.byKey(const Key('addImageButton')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('postContentField')),
      'My first post',
    );
    await tester.tap(find.byKey(const Key('submitPostButton')));
    await tester.pump(); // start async
    await tester.pump(); // finish async

    expect(repo.createPostCalled, isTrue);
    expect(repo.uploadPostImageCalled, isTrue);
  });
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class FakePostRepository implements PostRepository {
  bool createPostCalled = false;
  bool uploadPostImageCalled = false;

  @override
  Future<List<PostModel>> getPosts(String userId) async => [];

  @override
  Future<List<PostModel>> fetchFeed({int limit = 20, int offset = 0}) async => [];

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<PostModel> createPost(PostModel post) async {
    createPostCalled = true;
    return PostModel(
      id: 'new-id',
      userId: post.userId,
      caption: post.caption,
      imageUrl: post.imageUrl,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
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
