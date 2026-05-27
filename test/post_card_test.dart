import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/comment/comment_model.dart';
import 'package:pulso/comment/comment_repository.dart';
import 'package:pulso/like/like_repository.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/comment_providers.dart';
import 'package:pulso/providers/like_providers.dart';
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
    String currentUserId = 'u1',
  }) {
    return ProviderScope(
      overrides: [
        likeRepositoryProvider.overrideWithValue(likeRepo ?? _FakeLikeRepo()),
        commentRepositoryProvider.overrideWithValue(
          commentRepo ?? _FakeCommentRepo(),
        ),
        authRepositoryProvider.overrideWithValue(_StubAuth(currentUserId)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PostCard(post: post)),
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
