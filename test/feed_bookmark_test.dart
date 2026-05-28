import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/bookmark/bookmark_repository.dart';
import 'package:pulso/comment/comment_model.dart';
import 'package:pulso/comment/comment_repository.dart';
import 'package:pulso/follow/follow_repository.dart';
import 'package:pulso/like/like_repository.dart';
import 'package:pulso/notification/notification_model.dart';
import 'package:pulso/notification/notification_repository.dart';
import 'package:pulso/post/post_controller.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/bookmark_providers.dart';
import 'package:pulso/providers/comment_providers.dart';
import 'package:pulso/providers/follow_providers.dart';
import 'package:pulso/providers/like_providers.dart';
import 'package:pulso/providers/notification_providers.dart';
import 'package:pulso/providers/post_providers.dart';
import 'package:pulso/screens/feed_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('feed bookmark button toggles saved state', (tester) async {
    final bookmarkRepo = _FakeBookmarkRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          postControllerProvider.overrideWith(
            () => _SeededPostController([_post()]),
          ),
          bookmarkRepositoryProvider.overrideWithValue(bookmarkRepo),
          followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          likeRepositoryProvider.overrideWithValue(_FakeLikeRepository()),
          commentRepositoryProvider.overrideWithValue(_FakeCommentRepository()),
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(),
          ),
        ],
        child: const MaterialApp(home: FeedScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    await tester.pump();

    expect(bookmarkRepo.toggleCalls, 1);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}

PostModel _post() => PostModel(
  id: 'post-1',
  userId: 'author',
  caption: 'Bookmark this',
  imageUrl: '',
  imageUrls: const [],
  authorUsername: 'author',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

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

class _FakeBookmarkRepository implements BookmarkRepository {
  final Set<String> bookmarked = {};
  int toggleCalls = 0;

  @override
  Future<List<String>> getAllBookmarkedPostIds({
    required String userId,
  }) async => bookmarked.toList();

  @override
  Future<Set<String>> getBookmarkedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  }) async => bookmarked.intersection(postIds.toSet());

  @override
  Future<bool> toggleBookmark({
    required String postId,
    required String userId,
  }) async {
    toggleCalls++;
    if (bookmarked.contains(postId)) {
      bookmarked.remove(postId);
      return false;
    }
    bookmarked.add(postId);
    return true;
  }
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

class _FakeLikeRepository implements LikeRepository {
  @override
  Future<Set<String>> getLikedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  }) async => const {};

  @override
  Future<bool> isLikedByUser({
    required String postId,
    required String userId,
  }) async => false;

  @override
  Future<int> likeCount(String postId) async => 0;

  @override
  Future<Map<String, int>> likeCountsForPosts(List<String> postIds) async => {
    for (final id in postIds) id: 0,
  };

  @override
  RealtimeChannel subscribeToLikes({
    required void Function(String postId) onLikeChanged,
  }) => throw UnimplementedError();

  @override
  Future<bool> toggleLike({
    required String postId,
    required String userId,
  }) async => true;
}

class _FakeCommentRepository implements CommentRepository {
  @override
  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String body,
    String? parentCommentId,
  }) async => throw UnimplementedError();

  @override
  Future<List<CommentModel>> fetchReplies(String parentCommentId) async =>
      const [];

  @override
  Future<List<CommentModel>> hydrateMetadata(
    List<CommentModel> comments, {
    required String currentUserId,
  }) async => comments;

  @override
  Future<bool> toggleCommentLike({
    required String commentId,
    required String userId,
  }) async => true;

  @override
  Future<void> deleteComment(String commentId) async {}

  @override
  Future<List<CommentModel>> fetchComments(String postId) async => const [];

  @override
  Future<int> getCommentCount(String postId) async => 0;

  @override
  Future<Map<String, int>> getCommentCountsForPosts(
    List<String> postIds,
  ) async => {for (final id in postIds) id: 0};

  @override
  RealtimeChannel subscribeToComments({
    required String postId,
    required void Function(CommentModel comment) onCommentAdded,
    void Function(String commentId)? onCommentDeleted,
  }) => throw UnimplementedError();

  @override
  RealtimeChannel subscribeToAllComments({
    required void Function(String postId) onCommentAdded,
    required void Function(String postId) onCommentDeleted,
  }) => throw UnimplementedError();
}

class _FakeNotificationRepository implements NotificationRepository {
  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) async =>
      const [];

  @override
  Future<void> insertNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? postId,
    String? storyId,
  }) async {}

  @override
  Future<void> markAllRead(String userId) async {}

  @override
  RealtimeChannel subscribe(
    String userId,
    void Function(NotificationModel) onNew,
  ) => throw UnimplementedError();
}
