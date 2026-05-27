import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/follow/follow_repository.dart';
import 'package:pulso/providers/follow_providers.dart';

void main() {
  group('FollowRepository (in-memory contract)', () {
    test('follow inserts the relationship', () async {
      final repo = FakeFollowRepository();
      await repo.follow(followerId: 'a', followingId: 'b');

      expect(
        await repo.isFollowing(followerId: 'a', followingId: 'b'),
        isTrue,
      );
      expect(await repo.getFollowerCount('b'), 1);
      expect(await repo.getFollowingCount('a'), 1);
    });

    test('unfollow removes the relationship', () async {
      final repo = FakeFollowRepository();
      await repo.follow(followerId: 'a', followingId: 'b');
      await repo.unfollow(followerId: 'a', followingId: 'b');

      expect(
        await repo.isFollowing(followerId: 'a', followingId: 'b'),
        isFalse,
      );
      expect(await repo.getFollowerCount('b'), 0);
    });

    test('toggleFollow inserts then deletes', () async {
      final repo = FakeFollowRepository();
      final first =
          await repo.toggleFollow(followerId: 'a', followingId: 'b');
      expect(first, isTrue);
      expect(
        await repo.isFollowing(followerId: 'a', followingId: 'b'),
        isTrue,
      );

      final second =
          await repo.toggleFollow(followerId: 'a', followingId: 'b');
      expect(second, isFalse);
      expect(
        await repo.isFollowing(followerId: 'a', followingId: 'b'),
        isFalse,
      );
    });

    test('toggleFollow throws when a user tries to follow themselves',
        () async {
      final repo = FakeFollowRepository();
      expect(
        () => repo.toggleFollow(followerId: 'a', followingId: 'a'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('isFollowing returns bool', () async {
      final repo = FakeFollowRepository();
      final before =
          await repo.isFollowing(followerId: 'a', followingId: 'b');
      expect(before, isA<bool>());
      expect(before, isFalse);

      await repo.follow(followerId: 'a', followingId: 'b');
      final after =
          await repo.isFollowing(followerId: 'a', followingId: 'b');
      expect(after, isTrue);
    });

    test('getFollowingIds and getFollowerIds return the right ids', () async {
      final repo = FakeFollowRepository();
      await repo.follow(followerId: 'a', followingId: 'b');
      await repo.follow(followerId: 'a', followingId: 'c');
      await repo.follow(followerId: 'd', followingId: 'b');

      expect((await repo.getFollowingIds('a')).toSet(), {'b', 'c'});
      expect((await repo.getFollowerIds('b')).toSet(), {'a', 'd'});
    });
  });

  group('FollowController (uses FollowRepository contract)', () {
    test('toggleFollow optimistically flips the following state', () async {
      final repo = FakeFollowRepository();
      final container = ProviderContainer.test(
        overrides: [followRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(followControllerProvider.notifier).toggleFollow(
        currentUserId: 'a',
        targetUserId: 'b',
      );

      expect(
        container.read(followControllerProvider).isFollowing('b'),
        isTrue,
      );
      expect(
        container.read(followControllerProvider).statsFor('b').followers,
        1,
      );
    });

    test('toggleFollow no-ops when target is self', () async {
      final repo = FakeFollowRepository();
      final container = ProviderContainer.test(
        overrides: [followRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(followControllerProvider.notifier).toggleFollow(
        currentUserId: 'a',
        targetUserId: 'a',
      );

      expect(repo.toggleCalls, 0);
      expect(
        container.read(followControllerProvider).isFollowing('a'),
        isFalse,
      );
    });

    test('loadStats populates followers and following counts', () async {
      final repo = FakeFollowRepository();
      await repo.follow(followerId: 'a', followingId: 'b');
      await repo.follow(followerId: 'c', followingId: 'b');
      await repo.follow(followerId: 'b', followingId: 'd');

      final container = ProviderContainer.test(
        overrides: [followRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(followControllerProvider.notifier).loadStats('b');

      final stats = container.read(followControllerProvider).statsFor('b');
      expect(stats.followers, 2);
      expect(stats.following, 1);
    });
  });
}

// ── In-memory fake ─────────────────────────────────────────────────────────

class FakeFollowRepository implements FollowRepository {
  // Set of (followerId, followingId) tuples.
  final Set<String> _edges = <String>{};
  int toggleCalls = 0;

  String _key(String followerId, String followingId) =>
      '$followerId->$followingId';

  @override
  Future<bool> toggleFollow({
    required String followerId,
    required String followingId,
  }) async {
    toggleCalls++;
    if (followerId == followingId) {
      throw ArgumentError('A user cannot follow themselves.');
    }
    final key = _key(followerId, followingId);
    if (_edges.contains(key)) {
      _edges.remove(key);
      return false;
    }
    _edges.add(key);
    return true;
  }

  @override
  Future<void> follow({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) {
      throw ArgumentError('A user cannot follow themselves.');
    }
    _edges.add(_key(followerId, followingId));
  }

  @override
  Future<void> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    _edges.remove(_key(followerId, followingId));
  }

  @override
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    return _edges.contains(_key(followerId, followingId));
  }

  @override
  Future<int> getFollowerCount(String userId) async {
    return _edges.where((e) => e.endsWith('->$userId')).length;
  }

  @override
  Future<int> getFollowingCount(String userId) async {
    return _edges.where((e) => e.startsWith('$userId->')).length;
  }

  @override
  Future<List<String>> getFollowingIds(String userId) async {
    return _edges
        .where((e) => e.startsWith('$userId->'))
        .map((e) => e.split('->').last)
        .toList();
  }

  @override
  Future<List<String>> getFollowerIds(String userId) async {
    return _edges
        .where((e) => e.endsWith('->$userId'))
        .map((e) => e.split('->').first)
        .toList();
  }
}
