import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/post/post_repository.dart';

void main() {
  group('PostRepository (in-memory contract)', () {
    test('createPost stores the post and returns it with images', () async {
      final repo = FakePostRepository();
      final input = _samplePost(id: '', userId: 'u1', caption: 'hello');

      final created = await repo.createPost(
        input,
        extraImageUrls: ['https://img/2.png', 'https://img/3.png'],
      );

      expect(created.id, isNotEmpty);
      expect(created.userId, 'u1');
      expect(created.caption, 'hello');
      expect(created.imageUrls, [
        'https://img/1.png',
        'https://img/2.png',
        'https://img/3.png',
      ]);

      final byAuthor = await repo.getPosts('u1');
      expect(byAuthor, hasLength(1));
      expect(byAuthor.first.id, created.id);
    });

    test('getPosts is scoped to a single user and reverse-chronological',
        () async {
      final repo = FakePostRepository();
      await repo.createPost(_samplePost(userId: 'u1', caption: 'a'));
      await repo.createPost(_samplePost(userId: 'u2', caption: 'b'));
      await repo.createPost(_samplePost(userId: 'u1', caption: 'c'));

      final mine = await repo.getPosts('u1');
      expect(mine.map((p) => p.caption), ['c', 'a']);
    });

    test('fetchFeed returns all posts newest-first with pagination', () async {
      final repo = FakePostRepository();
      for (var i = 0; i < 5; i++) {
        await repo.createPost(_samplePost(userId: 'u1', caption: 'p$i'));
      }

      final firstPage = await repo.fetchFeed(limit: 2, offset: 0);
      final secondPage = await repo.fetchFeed(limit: 2, offset: 2);

      expect(firstPage.map((p) => p.caption), ['p4', 'p3']);
      expect(secondPage.map((p) => p.caption), ['p2', 'p1']);
    });

    test('fetchFollowingFeed returns empty when there are no follows',
        () async {
      final repo = FakePostRepository();
      await repo.createPost(_samplePost(userId: 'u1', caption: 'a'));

      final feed = await repo.fetchFollowingFeed(followingIds: []);
      expect(feed, isEmpty);
    });

    test('fetchFollowingFeed only returns posts from followed users',
        () async {
      final repo = FakePostRepository();
      await repo.createPost(_samplePost(userId: 'u1', caption: 'from-u1'));
      await repo.createPost(_samplePost(userId: 'u2', caption: 'from-u2'));
      await repo.createPost(_samplePost(userId: 'u3', caption: 'from-u3'));

      final feed = await repo.fetchFollowingFeed(followingIds: ['u1', 'u3']);
      expect(feed.map((p) => p.userId).toSet(), {'u1', 'u3'});
      expect(feed.any((p) => p.userId == 'u2'), isFalse);
    });

    test('updatePost mutates caption and refreshes updatedAt', () async {
      final repo = FakePostRepository();
      final created = await repo.createPost(
        _samplePost(userId: 'u1', caption: 'old'),
      );
      final originalUpdatedAt = created.updatedAt;

      final updated = await repo.updatePost(created.id, caption: 'new');

      expect(updated.id, created.id);
      expect(updated.caption, 'new');
      expect(updated.updatedAt.isAfter(originalUpdatedAt) ||
          updated.updatedAt.isAtSameMomentAs(originalUpdatedAt), isTrue);
    });

    test('deletePost removes the post from queries', () async {
      final repo = FakePostRepository();
      final a = await repo.createPost(_samplePost(userId: 'u1', caption: 'a'));
      await repo.createPost(_samplePost(userId: 'u1', caption: 'b'));

      await repo.deletePost(a.id);

      final mine = await repo.getPosts('u1');
      expect(mine.map((p) => p.caption), ['b']);
    });

    test('uploadPostImage returns a deterministic URL for the user', () async {
      final repo = FakePostRepository();
      final url = await repo.uploadPostImage(
        'u1',
        Uint8List.fromList([1, 2, 3]),
        'image/png',
      );
      expect(url, startsWith('https://fake/posts/u1/'));
    });

    test('uploadPostImages returns one URL per input image, in order',
        () async {
      final repo = FakePostRepository();
      final urls = await repo.uploadPostImages('u1', [
        (bytes: Uint8List.fromList([1]), mimeType: 'image/png'),
        (bytes: Uint8List.fromList([2]), mimeType: 'image/jpeg'),
        (bytes: Uint8List.fromList([3]), mimeType: 'image/png'),
      ]);

      expect(urls, hasLength(3));
      expect(urls[0], contains('_0'));
      expect(urls[1], contains('_1'));
      expect(urls[2], contains('_2'));
    });

    test('getPostsByIds returns empty for an empty list', () async {
      final repo = FakePostRepository();
      final result = await repo.getPostsByIds([]);
      expect(result, isEmpty);
    });

    test('getPostsByIds returns only the requested posts', () async {
      final repo = FakePostRepository();
      final a = await repo.createPost(_samplePost(userId: 'u1', caption: 'a'));
      await repo.createPost(_samplePost(userId: 'u1', caption: 'b'));
      final c = await repo.createPost(_samplePost(userId: 'u2', caption: 'c'));

      final result = await repo.getPostsByIds([a.id, c.id, 'missing']);
      expect(result.map((p) => p.id).toSet(), {a.id, c.id});
    });
  });
}

PostModel _samplePost({
  String id = '',
  required String userId,
  required String caption,
}) {
  final now = DateTime.now();
  return PostModel(
    id: id,
    userId: userId,
    caption: caption,
    imageUrl: 'https://img/1.png',
    imageUrls: const ['https://img/1.png'],
    createdAt: now,
    updatedAt: now,
  );
}

// ── In-memory fake ─────────────────────────────────────────────────────────

class FakePostRepository implements PostRepository {
  final List<PostModel> _posts = [];
  int _nextId = 1;

  @override
  Future<List<PostModel>> getPosts(String userId) async {
    final scoped = _posts.where((p) => p.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return scoped;
  }

  @override
  Future<List<PostModel>> fetchFeed({int limit = 20, int offset = 0}) async {
    final sorted = [..._posts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset >= sorted.length) return [];
    final end = (offset + limit).clamp(0, sorted.length);
    return sorted.sublist(offset, end);
  }

  @override
  Future<List<PostModel>> fetchFollowingFeed({
    required List<String> followingIds,
    int limit = 20,
    int offset = 0,
  }) async {
    if (followingIds.isEmpty) return [];
    final ids = followingIds.toSet();
    final scoped = _posts.where((p) => ids.contains(p.userId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset >= scoped.length) return [];
    final end = (offset + limit).clamp(0, scoped.length);
    return scoped.sublist(offset, end);
  }

  @override
  Future<PostModel> createPost(
    PostModel post, {
    List<String> extraImageUrls = const [],
  }) async {
    final id = 'post-${_nextId++}';
    final now = DateTime.now().add(Duration(milliseconds: _nextId));
    final stored = PostModel(
      id: id,
      userId: post.userId,
      caption: post.caption,
      imageUrl: post.imageUrl,
      imageUrls: [post.imageUrl, ...extraImageUrls],
      createdAt: now,
      updatedAt: now,
    );
    _posts.add(stored);
    return stored;
  }

  @override
  Future<PostModel> updatePost(
    String postId, {
    required String caption,
  }) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) {
      throw StateError('Post $postId not found');
    }
    final original = _posts[index];
    final updated = PostModel(
      id: original.id,
      userId: original.userId,
      caption: caption,
      imageUrl: original.imageUrl,
      imageUrls: original.imageUrls,
      createdAt: original.createdAt,
      updatedAt: DateTime.now().add(const Duration(milliseconds: 1)),
    );
    _posts[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePost(String postId) async {
    _posts.removeWhere((p) => p.id == postId);
  }

  @override
  Future<String> uploadPostImage(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}';
    return 'https://fake/posts/$path';
  }

  @override
  Future<List<String>> uploadPostImages(
    String userId,
    List<({Uint8List bytes, String mimeType})> images,
  ) async {
    final base = DateTime.now().millisecondsSinceEpoch;
    return [
      for (var i = 0; i < images.length; i++)
        'https://fake/posts/$userId/${base}_$i',
    ];
  }

  @override
  Future<List<PostModel>> getPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final wanted = ids.toSet();
    final result = _posts.where((p) => wanted.contains(p.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}
