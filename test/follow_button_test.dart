import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/follow/follow_repository.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/follow_providers.dart';
import 'package:pulso/widgets/follow_button.dart';

void main() {
  Widget build({
    required FollowRepository repo,
    required AuthRepository auth,
    required String targetUserId,
  }) {
    return ProviderScope(
      overrides: [
        followRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: FollowButton(targetUserId: targetUserId)),
        ),
      ),
    );
  }

  testWidgets('renders Follow label when not following', (tester) async {
    await tester.pumpWidget(
      build(
        repo: _FakeFollowRepo(),
        auth: _StubAuth('me'),
        targetUserId: 'other',
      ),
    );
    await tester.pump();

    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('hides itself when the target is the current user',
      (tester) async {
    await tester.pumpWidget(
      build(
        repo: _FakeFollowRepo(),
        auth: _StubAuth('me'),
        targetUserId: 'me',
      ),
    );
    await tester.pump();

    expect(find.text('Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('tap toggles to Following label', (tester) async {
    final repo = _FakeFollowRepo();
    await tester.pumpWidget(
      build(
        repo: repo,
        auth: _StubAuth('me'),
        targetUserId: 'other',
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('follow_button_other')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Following'), findsOneWidget);
    expect(repo.toggleCalls, 1);
  });
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class _FakeFollowRepo implements FollowRepository {
  final Set<String> _edges = <String>{};
  int toggleCalls = 0;

  String _key(String a, String b) => '$a->$b';

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
  }) async =>
      _edges.contains(_key(followerId, followingId));

  @override
  Future<int> getFollowerCount(String userId) async =>
      _edges.where((e) => e.endsWith('->$userId')).length;

  @override
  Future<int> getFollowingCount(String userId) async =>
      _edges.where((e) => e.startsWith('$userId->')).length;

  @override
  Future<List<String>> getFollowingIds(String userId) async => _edges
      .where((e) => e.startsWith('$userId->'))
      .map((e) => e.split('->').last)
      .toList();

  @override
  Future<List<String>> getFollowerIds(String userId) async => _edges
      .where((e) => e.endsWith('->$userId'))
      .map((e) => e.split('->').first)
      .toList();
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
