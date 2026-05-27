import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/comment/comment_model.dart';
import 'package:pulso/comment/comment_repository.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/comment_providers.dart';
import 'package:pulso/widgets/comment_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Widget build({
    required CommentRepository repo,
    String currentUserId = 'me',
  }) {
    return ProviderScope(
      overrides: [
        commentRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(_StubAuth(currentUserId)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: CommentInput(postId: 'p1')),
      ),
    );
  }

  testWidgets('Post button is disabled when the field is empty',
      (tester) async {
    await tester.pumpWidget(build(repo: _FakeRepo()));
    await tester.pump();

    final btn = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Post'));
    expect(btn.onPressed, isNull);
  });

  testWidgets('Post button enables once text is entered', (tester) async {
    await tester.pumpWidget(build(repo: _FakeRepo()));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('comment_input_p1')),
      'Hello world',
    );
    await tester.pump();

    final btn = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Post'));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('tapping Post submits via CommentController', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(build(repo: repo));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('comment_input_p1')),
      'A new comment',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Post'));
    await tester.pump();
    await tester.pump();

    expect(repo.addCalls, 1);
    expect(repo.lastBody, 'A new comment');
  });
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class _FakeRepo implements CommentRepository {
  int addCalls = 0;
  String? lastBody;
  int _nextId = 1;

  @override
  Future<List<CommentModel>> fetchComments(String postId) async => [];

  @override
  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String body,
  }) async {
    addCalls++;
    lastBody = body;
    return CommentModel(
      id: 'c${_nextId++}',
      postId: postId,
      userId: userId,
      body: body,
      createdAt: DateTime(2024),
    );
  }

  @override
  Future<void> deleteComment(String commentId) async {}

  @override
  Future<int> getCommentCount(String postId) async => 0;

  @override
  Future<Map<String, int>> getCommentCountsForPosts(
    List<String> postIds,
  ) async =>
      {for (final id in postIds) id: 0};

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
