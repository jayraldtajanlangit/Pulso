import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulso/post/post_controller.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/profile/profile_repository.dart';
import 'package:pulso/providers/post_providers.dart';
import 'package:pulso/providers/profile_providers.dart';
import 'package:pulso/screens/explore_screen.dart';

void main() {
  testWidgets('filters explore posts by username or caption', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postControllerProvider.overrideWith(
            () => _SeededPostController([
              _post(id: 'p1', username: 'alice', caption: 'Morning coffee'),
              _post(id: 'p2', username: 'bob', caption: 'Night market'),
            ]),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
        child: const MaterialApp(home: ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.article_outlined), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
  });

  testWidgets('search also shows matching user profiles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          postControllerProvider.overrideWith(
            () => _SeededPostController([
              _post(id: 'p1', username: 'alice', caption: 'Morning coffee'),
            ]),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
        child: const MaterialApp(home: ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pumpAndSettle();

    expect(find.text('alice_profile'), findsOneWidget);
    expect(find.text('Alice Profile'), findsOneWidget);
  });
}

PostModel _post({
  required String id,
  required String username,
  required String caption,
}) {
  return PostModel(
    id: id,
    userId: username,
    caption: caption,
    imageUrl: '',
    imageUrls: const [],
    authorUsername: username,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

class _SeededPostController extends PostController {
  _SeededPostController(this._posts);

  final List<PostModel> _posts;

  @override
  PostState build() => PostState(
    isLoading: false,
    isLoadingMore: false,
    isCreating: false,
    hasMore: false,
    posts: _posts,
    pendingImages: const [],
  );

  @override
  Future<void> loadFeed({int limit = kFeedPageSize}) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<ProfileModel?> getProfile(String userId) async => null;

  @override
  Future<List<ProfileModel>> searchProfiles(String query) async => [
    ProfileModel(
      id: 'alice-id',
      username: 'alice_profile',
      displayName: 'Alice Profile',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  ];

  @override
  Future<ProfileModel> upsertProfile(ProfileModel profile) async => profile;

  @override
  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async => '';
}
