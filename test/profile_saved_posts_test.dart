import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/bookmark/bookmark_repository.dart';
import 'package:pulso/follow/follow_repository.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/post/post_repository.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/profile/profile_repository.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/bookmark_providers.dart';
import 'package:pulso/providers/follow_providers.dart';
import 'package:pulso/providers/post_providers.dart';
import 'package:pulso/providers/profile_providers.dart';
import 'package:pulso/screens/profile_screen.dart';

void main() {
  testWidgets('saved tab shows bookmarked posts on the profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
          followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          bookmarkRepositoryProvider.overrideWithValue(
            _FakeBookmarkRepository(),
          ),
          postRepositoryProvider.overrideWithValue(_FakePostRepository()),
        ],
        child: const MaterialApp(
          home: ProfileScreen(userId: 'me', isOwnProfile: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.text('No saved posts'), findsNothing);
  });
}

class _StubAuthRepository implements AuthRepository {
  final _session = const AppAuthSession(userId: 'me', email: 'me@example.com');

  @override
  AppAuthSession? get currentSession => _session;

  @override
  Stream<AppAuthSession?> get authStateChanges =>
      Stream<AppAuthSession?>.value(_session);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<ProfileModel?> getProfile(String userId) async => ProfileModel(
    id: userId,
    username: 'me',
    displayName: 'Me',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  @override
  Future<List<ProfileModel>> searchProfiles(String query) async => const [];

  @override
  Future<ProfileModel> upsertProfile(ProfileModel profile) async => profile;

  @override
  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async => 'https://example.com/avatar.jpg';
}

class _FakeBookmarkRepository implements BookmarkRepository {
  @override
  Future<List<String>> getAllBookmarkedPostIds({
    required String userId,
  }) async => const ['saved-1'];

  @override
  Future<Set<String>> getBookmarkedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  }) async => {'saved-1'};

  @override
  Future<bool> toggleBookmark({
    required String postId,
    required String userId,
  }) async => true;
}

class _FakePostRepository implements PostRepository {
  @override
  Future<List<PostModel>> getPosts(String userId) async => const [];

  @override
  Future<List<PostModel>> getPostsByIds(List<String> ids) async => [
    PostModel(
      id: 'saved-1',
      userId: 'author',
      caption: 'Saved post',
      imageUrl: '',
      imageUrls: const [],
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  ];

  @override
  Future<List<PostModel>> fetchFeed({int limit = 20, int offset = 0}) async =>
      const [];

  @override
  Future<List<PostModel>> fetchFollowingFeed({
    required List<String> followingIds,
    int limit = 20,
    int offset = 0,
  }) async => const [];

  @override
  Future<PostModel> createPost(
    PostModel post, {
    List<String> extraImageUrls = const [],
  }) async => post;

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<PostModel> updatePost(
    String postId, {
    required String caption,
  }) async => throw UnimplementedError();

  @override
  Future<String> uploadPostImage(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async => '';

  @override
  Future<List<String>> uploadPostImages(
    String userId,
    List<({Uint8List bytes, String mimeType})> images,
  ) async => const [];
}

class _FakeFollowRepository implements FollowRepository {
  @override
  Future<void> follow({
    required String followerId,
    required String followingId,
  }) async {}

  @override
  Future<int> getFollowerCount(String userId) async => 0;

  @override
  Future<List<String>> getFollowerIds(String userId) async => const [];

  @override
  Future<List<ProfileModel>> getFollowerProfiles(String userId) async =>
      const [];

  @override
  Future<int> getFollowingCount(String userId) async => 0;

  @override
  Future<List<String>> getFollowingIds(String userId) async => const [];

  @override
  Future<List<ProfileModel>> getFollowingProfiles(String userId) async =>
      const [];

  @override
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async => false;

  @override
  Future<bool> toggleFollow({
    required String followerId,
    required String followingId,
  }) async => true;

  @override
  Future<void> unfollow({
    required String followerId,
    required String followingId,
  }) async {}
}
