import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/like/like_repository.dart';
import 'package:pulso/providers/like_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('LikeRepository (in-memory contract)', () {
    test('toggleLike inserts when no like exists, returns true', () async {
      final repo = FakeLikeRepository();
      final result = await repo.toggleLike(postId: 'p1', userId: 'u1');

      expect(result, isTrue);
      expect(await repo.getLikeCount('p1'), 1);
      expect(
        await repo.isLikedByUser(postId: 'p1', userId: 'u1'),
        isTrue,
      );
    });

    test('toggleLike removes when a like exists, returns false', () async {
      final repo = FakeLikeRepository();
      await repo.toggleLike(postId: 'p1', userId: 'u1');
      final result = await repo.toggleLike(postId: 'p1', userId: 'u1');

      expect(result, isFalse);
      expect(await repo.getLikeCount('p1'), 0);
      expect(
        await repo.isLikedByUser(postId: 'p1', userId: 'u1'),
        isFalse,
      );
    });

    test('getLikeCount returns an integer (count of distinct likes)',
        () async {
      final repo = FakeLikeRepository();
      await repo.toggleLike(postId: 'p1', userId: 'u1');
      await repo.toggleLike(postId: 'p1', userId: 'u2');
      await repo.toggleLike(postId: 'p1', userId: 'u3');

      final count = await repo.getLikeCount('p1');
      expect(count, isA<int>());
      expect(count, 3);
    });

    test('getLikeCountsForPosts returns 0 for posts with no likes', () async {
      final repo = FakeLikeRepository();
      await repo.toggleLike(postId: 'p1', userId: 'u1');

      final counts = await repo.getLikeCountsForPosts(['p1', 'p2', 'p3']);
      expect(counts['p1'], 1);
      expect(counts['p2'], 0);
      expect(counts['p3'], 0);
    });

    test('getLikedPostIdsForUser only returns posts liked by that user',
        () async {
      final repo = FakeLikeRepository();
      await repo.toggleLike(postId: 'p1', userId: 'u1');
      await repo.toggleLike(postId: 'p2', userId: 'u1');
      await repo.toggleLike(postId: 'p1', userId: 'u2'); // other user

      final liked = await repo.getLikedPostIdsForUser(
        userId: 'u1',
        postIds: ['p1', 'p2', 'p3'],
      );
      expect(liked, {'p1', 'p2'});
    });
  });

  group('LikeController (uses LikeRepository contract)', () {
    test('toggle optimistically flips like state', () async {
      final repo = FakeLikeRepository();
      final container = ProviderContainer.test(
        overrides: [likeRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(likeControllerProvider.notifier)
          .toggle(postId: 'p1', currentUserId: 'u1');

      final status =
          container.read(likeControllerProvider).statusFor('p1');
      expect(status.isLiked, isTrue);
      expect(status.count, 1);
    });

    test('loadForPosts hydrates counts and per-user state', () async {
      final repo = FakeLikeRepository();
      await repo.toggleLike(postId: 'p1', userId: 'u1');
      await repo.toggleLike(postId: 'p1', userId: 'u2');
      await repo.toggleLike(postId: 'p2', userId: 'u2');

      final container = ProviderContainer.test(
        overrides: [likeRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(likeControllerProvider.notifier)
          .loadForPosts(postIds: ['p1', 'p2', 'p3'], currentUserId: 'u1');

      final state = container.read(likeControllerProvider);
      expect(state.statusFor('p1').count, 2);
      expect(state.statusFor('p1').isLiked, isTrue);
      expect(state.statusFor('p2').count, 1);
      expect(state.statusFor('p2').isLiked, isFalse);
      expect(state.statusFor('p3').count, 0);
    });

    test('toggle reverts optimistic state when repository throws', () async {
      final repo = FakeLikeRepository(failOnToggle: true);
      final container = ProviderContainer.test(
        overrides: [likeRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(likeControllerProvider.notifier)
          .toggle(postId: 'p1', currentUserId: 'u1');

      final status =
          container.read(likeControllerProvider).statusFor('p1');
      expect(status.isLiked, isFalse);
      expect(status.count, 0);
      expect(
        container.read(likeControllerProvider).errorMessage,
        isNotNull,
      );
    });
  });
}

// ── In-memory fake ─────────────────────────────────────────────────────────

class FakeLikeRepository implements LikeRepository {
  FakeLikeRepository({this.failOnToggle = false});

  final bool failOnToggle;
  final Map<String, Set<String>> _likes = {}; // postId -> {userIds}

  @override
  Future<bool> toggleLike({
    required String postId,
    required String userId,
  }) async {
    if (failOnToggle) {
      throw Exception('simulated failure');
    }
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
  }) async {
    return _likes[postId]?.contains(userId) ?? false;
  }

  @override
  Future<int> getLikeCount(String postId) async {
    return _likes[postId]?.length ?? 0;
  }

  @override
  Future<Map<String, int>> getLikeCountsForPosts(List<String> postIds) async {
    return {for (final id in postIds) id: _likes[id]?.length ?? 0};
  }

  @override
  Future<Set<String>> getLikedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  }) async {
    return {
      for (final id in postIds)
        if (_likes[id]?.contains(userId) ?? false) id,
    };
  }

  @override
  RealtimeChannel subscribeToLikes({
    required void Function(String postId) onLikeChanged,
  }) {
    // Not exercised in unit tests.
    throw UnimplementedError();
  }
}
