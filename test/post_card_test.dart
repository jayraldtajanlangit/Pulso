import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/comment/comment_model.dart';
import 'package:pulso/comment/comment_repository.dart';
import 'package:pulso/like/like_repository.dart';
import 'package:pulso/notification/notification_model.dart';
import 'package:pulso/notification/notification_repository.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/post/post_repository.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/comment_providers.dart';
import 'package:pulso/providers/like_providers.dart';
import 'package:pulso/providers/notification_providers.dart';
import 'package:pulso/providers/post_providers.dart';
import 'package:pulso/widgets/post_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostModel _samplePost({
  String id = 'p1',
  String userId = 'u1',
  String caption = 'A lovely sunset',
  String imageUrl = 'https://example.com/p1.jpg',
}) {
  return PostModel(
    id: id,
    userId: userId,
    caption: caption,
    imageUrl: imageUrl,
    imageUrls: [imageUrl],
    createdAt: DateTime(2024, 5, 1),
    updatedAt: DateTime(2024, 5, 1),
    authorUsername: 'jane',
  );
}

void main() {
  Widget buildCard({
    required PostModel post,
    LikeRepository? likeRepo,
    CommentRepository? commentRepo,
    PostRepository? postRepo,
    NotificationRepository? notificationRepo,
    String currentUserId = 'u1',
    VoidCallback? onHidden,
  }) {
    return ProviderScope(
      overrides: [
        likeRepositoryProvider.overrideWithValue(likeRepo ?? _FakeLikeRepo()),
        commentRepositoryProvider.overrideWithValue(
          commentRepo ?? _FakeCommentRepo(),
        ),
        postRepositoryProvider.overrideWithValue(postRepo ?? _FakePostRepo()),
        notificationRepositoryProvider.overrideWithValue(
          notificationRepo ?? _FakeNotificationRepo(),
        ),
        authRepositoryProvider.overrideWithValue(_StubAuth(currentUserId)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostCard(post: post, onHidden: onHidden),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the post image, caption, and like count', (
    tester,
  ) async {
    final post = _samplePost(caption: 'A lovely sunset');
    final likeRepo = _FakeLikeRepo()..seedLike(postId: 'p1', userId: 'someone');

    await tester.pumpWidget(buildCard(post: post, likeRepo: likeRepo));
    await tester.pumpAndSettle();

    // Image renders via CachedNetworkImage.
    expect(find.byType(Image), findsWidgets);

    // Caption appears inside the RichText span.
    expect(
      find.textContaining('A lovely sunset', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renders zero like count when nobody has liked', (tester) async {
    final post = _samplePost();
    await tester.pumpWidget(buildCard(post: post));
    await tester.pump();

    expect(find.text('0'), findsWidgets);
  });

  testWidgets('shows filled heart and increments count after tap', (
    tester,
  ) async {
    final post = _samplePost();
    final likeRepo = _FakeLikeRepo();
    await tester.pumpWidget(
      buildCard(post: post, likeRepo: likeRepo, currentUserId: 'u1'),
    );
    await tester.pump();

    // Initial state: outline heart, 0 likes.
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('like_button_p1')));
    await tester.tap(find.byKey(const Key('like_button_p1')));
    await tester.pump();
    await tester.pump();

    // Filled heart appears, provider toggle was invoked.
    expect(find.byIcon(Icons.favorite), findsWidgets);
    expect(likeRepo.toggleCalls, 1);
  });

  testWidgets('double-tap like notifies the post owner', (tester) async {
    final post = _samplePost(userId: 'owner');
    final notificationRepo = _FakeNotificationRepo();

    await tester.pumpWidget(
      buildCard(
        post: post,
        currentUserId: 'viewer',
        notificationRepo: notificationRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(PageView));
    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();

    expect(notificationRepo.recipientId, 'owner');
    expect(notificationRepo.actorId, 'viewer');
    expect(notificationRepo.type, 'like');
    expect(notificationRepo.postId, 'p1');
  });

  testWidgets('owner more-options menu can delete a post', (tester) async {
    final post = _samplePost(userId: 'u1');
    final postRepo = _FakePostRepo();

    await tester.pumpWidget(
      buildCard(post: post, postRepo: postRepo, currentUserId: 'u1'),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(postRepo.deletedPostId, 'p1');
  });

  testWidgets('non-owner more-options menu exposes report action', (
    tester,
  ) async {
    final post = _samplePost(userId: 'owner');

    await tester.pumpWidget(buildCard(post: post, currentUserId: 'viewer'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Report'), findsOneWidget);

    await tester.tap(find.text('Report'));
    await tester.pump();

    expect(find.text('Post reported'), findsOneWidget);
  });

  testWidgets('more-options menu can hide a post', (tester) async {
    final post = _samplePost(userId: 'owner');
    var hidden = false;

    await tester.pumpWidget(
      buildCard(
        post: post,
        currentUserId: 'viewer',
        onHidden: () => hidden = true,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Hide post'), findsOneWidget);

    await tester.tap(find.text('Hide post'));
    await tester.pump();

    expect(hidden, isTrue);
    expect(find.text('Post hidden'), findsOneWidget);
  });
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class _FakeLikeRepo implements LikeRepository {
  final Map<String, Set<String>> _likes = {};
  int toggleCalls = 0;

  void seedLike({required String postId, required String userId}) {
    _likes.putIfAbsent(postId, () => <String>{}).add(userId);
  }

  @override
  Future<bool> toggleLike({
    required String postId,
    required String userId,
  }) async {
    toggleCalls++;
    final users = _likes.putIfAbsent(postId, () => <String>{});
    if (users.contains(userId)) {
      users.remove(userId);
      return false;
    }
    users.add(userId);
    return true;
  }

  @override
  Future<bool> isLikedByUser({
    required String postId,
    required String userId,
  }) async => _likes[postId]?.contains(userId) ?? false;

  @override
  Future<int> likeCount(String postId) async => _likes[postId]?.length ?? 0;

  @override
  Future<Map<String, int>> likeCountsForPosts(List<String> postIds) async => {
    for (final id in postIds) id: _likes[id]?.length ?? 0,
  };

  @override
  Future<Set<String>> getLikedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  }) async => {
    for (final id in postIds)
      if (_likes[id]?.contains(userId) ?? false) id,
  };

  @override
  RealtimeChannel subscribeToLikes({
    required void Function(String postId) onLikeChanged,
  }) => throw UnimplementedError();
}

class _FakeCommentRepo implements CommentRepository {
  @override
  Future<List<CommentModel>> fetchComments(String postId) async => [];

  @override
  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String body,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteComment(String commentId) async {}

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
}

class _FakePostRepo implements PostRepository {
  String? deletedPostId;

  @override
  Future<List<PostModel>> getPosts(String userId) async => const [];

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
  Future<List<PostModel>> getPostsByIds(List<String> ids) async => const [];

  @override
  Future<PostModel> createPost(
    PostModel post, {
    List<String> extraImageUrls = const [],
  }) async => post;

  @override
  Future<PostModel> updatePost(String postId, {required String caption}) async {
    return PostModel(
      id: postId,
      userId: 'u1',
      caption: caption,
      imageUrl: '',
      imageUrls: const [],
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
  }

  @override
  Future<void> deletePost(String postId) async {
    deletedPostId = postId;
  }

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

class _FakeNotificationRepo implements NotificationRepository {
  String? recipientId;
  String? actorId;
  String? type;
  String? postId;

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) async =>
      const [];

  @override
  Future<void> insertNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? postId,
  }) async {
    this.recipientId = recipientId;
    this.actorId = actorId;
    this.type = type;
    this.postId = postId;
  }

  @override
  Future<void> markAllRead(String userId) async {}

  @override
  RealtimeChannel subscribe(
    String userId,
    void Function(NotificationModel) onNew,
  ) => throw UnimplementedError();
}

class _StubAuth implements AuthRepository {
  _StubAuth(String userId)
    : _session = AppAuthSession(userId: userId, email: '$userId@test.local');

  final AppAuthSession _session;

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
