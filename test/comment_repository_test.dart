import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/comment/comment_model.dart';
import 'package:pulso/comment/comment_repository.dart';
import 'package:pulso/providers/comment_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('CommentRepository (in-memory contract)', () {
    test('addComment persists the new comment and returns it', () async {
      final repo = FakeCommentRepository();
      final created = await repo.addComment(
        postId: 'p1',
        userId: 'u1',
        body: 'first comment',
      );

      expect(created.id, isNotEmpty);
      expect(created.postId, 'p1');
      expect(created.userId, 'u1');
      expect(created.body, 'first comment');

      final all = await repo.fetchComments('p1');
      expect(all.length, 1);
      expect(all.first.body, 'first comment');
    });

    test('fetchComments returns a post-scoped list, ordered by creation',
        () async {
      final repo = FakeCommentRepository();
      await repo.addComment(postId: 'p1', userId: 'u1', body: 'first');
      await repo.addComment(postId: 'p2', userId: 'u1', body: 'on other post');
      await repo.addComment(postId: 'p1', userId: 'u2', body: 'second');

      final scoped = await repo.fetchComments('p1');
      expect(scoped.length, 2);
      expect(scoped[0].body, 'first');
      expect(scoped[1].body, 'second');
    });

    test('deleteComment removes the comment from the post', () async {
      final repo = FakeCommentRepository();
      final c = await repo.addComment(postId: 'p1', userId: 'u1', body: 'x');
      await repo.addComment(postId: 'p1', userId: 'u2', body: 'y');

      await repo.deleteComment(c.id);

      final remaining = await repo.fetchComments('p1');
      expect(remaining.length, 1);
      expect(remaining.first.body, 'y');
    });

    test('getCommentCount and getCommentCountsForPosts return ints', () async {
      final repo = FakeCommentRepository();
      await repo.addComment(postId: 'p1', userId: 'u1', body: 'a');
      await repo.addComment(postId: 'p1', userId: 'u2', body: 'b');
      await repo.addComment(postId: 'p2', userId: 'u1', body: 'c');

      expect(await repo.getCommentCount('p1'), 2);
      expect(await repo.getCommentCount('p2'), 1);
      expect(await repo.getCommentCount('p3'), 0);

      final counts =
          await repo.getCommentCountsForPosts(['p1', 'p2', 'p3']);
      expect(counts, {'p1': 2, 'p2': 1, 'p3': 0});
    });
  });

  group('CommentController (uses CommentRepository contract)', () {
    test('addComment appends to the thread and updates count', () async {
      final repo = FakeCommentRepository();
      final container = ProviderContainer.test(
        overrides: [commentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(commentControllerProvider.notifier).addComment(
        postId: 'p1',
        userId: 'u1',
        body: 'Hello',
      );

      final thread =
          container.read(commentControllerProvider).threadFor('p1');
      expect(thread.comments.length, 1);
      expect(thread.comments.first.body, 'Hello');
      expect(
        container.read(commentControllerProvider).countFor('p1'),
        1,
      );
    });

    test('addComment rejects empty body without calling repo', () async {
      final repo = FakeCommentRepository();
      final container = ProviderContainer.test(
        overrides: [commentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(commentControllerProvider.notifier).addComment(
        postId: 'p1',
        userId: 'u1',
        body: '   ',
      );

      expect(repo.addCommentCalls, 0);
      expect(
        container
            .read(commentControllerProvider)
            .threadFor('p1')
            .errorMessage,
        'Comment cannot be empty.',
      );
    });

    test('deleteComment optimistically removes from thread', () async {
      final repo = FakeCommentRepository();
      final container = ProviderContainer.test(
        overrides: [commentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      // Seed via controller.
      await container.read(commentControllerProvider.notifier).addComment(
        postId: 'p1',
        userId: 'u1',
        body: 'first',
      );
      final created = container
          .read(commentControllerProvider)
          .threadFor('p1')
          .comments
          .first;

      await container.read(commentControllerProvider.notifier).deleteComment(
        postId: 'p1',
        commentId: created.id,
      );

      final thread =
          container.read(commentControllerProvider).threadFor('p1');
      expect(thread.comments, isEmpty);
      expect(
        container.read(commentControllerProvider).countFor('p1'),
        0,
      );
    });
  });
}

// ── In-memory fake ─────────────────────────────────────────────────────────

class FakeCommentRepository implements CommentRepository {
  final List<CommentModel> _comments = [];
  int _nextId = 1;
  int addCommentCalls = 0;

  @override
  Future<List<CommentModel>> fetchComments(String postId) async {
    final scoped = _comments.where((c) => c.postId == postId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return scoped;
  }

  @override
  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String body,
  }) async {
    addCommentCalls++;
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
  Future<int> getCommentCount(String postId) async {
    return _comments.where((c) => c.postId == postId).length;
  }

  @override
  Future<Map<String, int>> getCommentCountsForPosts(
    List<String> postIds,
  ) async {
    return {
      for (final id in postIds)
        id: _comments.where((c) => c.postId == id).length,
    };
  }

  @override
  RealtimeChannel subscribeToComments({
    required String postId,
    required void Function(CommentModel comment) onCommentAdded,
    void Function(String commentId)? onCommentDeleted,
  }) {
    // Subscription is not exercised in unit tests.
    throw UnimplementedError();
  }
}
