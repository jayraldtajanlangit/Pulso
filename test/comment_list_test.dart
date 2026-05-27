import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/comment/comment_model.dart';
import 'package:pulso/comment/comment_repository.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/comment_providers.dart';
import 'package:pulso/widgets/comment_list.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Widget build({
    required CommentRepository repo,
    String currentUserId = 'me',
    String postOwnerId = 'someone-else',
  }) {
    return ProviderScope(
      overrides: [
        commentRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(_StubAuth(currentUserId)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CommentList(
            postId: 'p1',
            postOwnerId: postOwnerId,
          ),
        ),
      ),
    );
  }

  testWidgets('shows empty state when no comments exist', (tester) async {
    await tester.pumpWidget(build(repo: _FakeCommentRepo()));
    await tester.pumpAndSettle();

    expect(find.text('No comments yet. Be the first!'), findsOneWidget);
  });

  testWidgets('renders each comment with body text and author', (tester) async {
    final repo = _FakeCommentRepo(seed: [
      CommentModel(
        id: 'c1',
        postId: 'p1',
        userId: 'u1',
        body: 'Great post!',
        createdAt: DateTime(2024),
        authorUsername: 'janedoe',
      ),
      CommentModel(
        id: 'c2',
        postId: 'p1',
        userId: 'u2',
        body: 'Agreed.',
        createdAt: DateTime(2024).add(const Duration(seconds: 1)),
        authorUsername: 'johndoe',
      ),
    ]);

    await tester.pumpWidget(build(repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Great post!', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Agreed.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('comment author can delete their own comment', (tester) async {
    final repo = _FakeCommentRepo(seed: [
      CommentModel(
        id: 'c1',
        postId: 'p1',
        userId: 'me', // same as current user
        body: 'mine',
        createdAt: DateTime(2024),
      ),
    ]);

    await tester.pumpWidget(build(repo: repo, currentUserId: 'me'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('non-author non-owner cannot delete', (tester) async {
    final repo = _FakeCommentRepo(seed: [
      CommentModel(
        id: 'c1',
        postId: 'p1',
        userId: 'other',
        body: 'not mine',
        createdAt: DateTime(2024),
      ),
    ]);

    await tester.pumpWidget(
      build(
        repo: repo,
        currentUserId: 'me',
        postOwnerId: 'someone-else',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class _FakeCommentRepo implements CommentRepository {
  _FakeCommentRepo({List<CommentModel>? seed})
      : _comments = List<CommentModel>.from(seed ?? const []);

  final List<CommentModel> _comments;
  int _nextId = 100;

  @override
  Future<List<CommentModel>> fetchComments(String postId) async {
    return _comments.where((c) => c.postId == postId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String body,
  }) async {
    final created = CommentModel(
      id: 'c${_nextId++}',
      postId: postId,
      userId: userId,
      body: body,
      createdAt: DateTime(2024).add(Duration(seconds: _nextId)),
    );
    _comments.add(created);
    return created;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    _comments.removeWhere((c) => c.id == commentId);
  }

  @override
  Future<int> getCommentCount(String postId) async =>
      _comments.where((c) => c.postId == postId).length;

  @override
  Future<Map<String, int>> getCommentCountsForPosts(
    List<String> postIds,
  ) async =>
      {for (final id in postIds) id: _comments.where((c) => c.postId == id).length};

  @override
  RealtimeChannel subscribeToComments({
    required String postId,
    required void Function(CommentModel comment) onCommentAdded,
    void Function(String commentId)? onCommentDeleted,
  }) =>
      throw UnimplementedError();
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
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({required String email, required String password}) async {}
}
