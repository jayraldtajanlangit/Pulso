import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/like/like_repository.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/like_providers.dart';
import 'package:pulso/widgets/like_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Widget buildButton({
    required LikeRepository repo,
    required AuthRepository auth,
  }) {
    return ProviderScope(
      overrides: [
        likeRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: LikeButton(postId: 'p1')),
        ),
      ),
    );
  }

  testWidgets('renders unfilled heart by default', (tester) async {
    await tester.pumpWidget(
      buildButton(
        repo: _FakeLikeRepo(),
        auth: _StubAuthRepository(userId: 'u1'),
      ),
    );

    // Allow ConsumerWidget watch().
    await tester.pump();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('tapping toggles to filled heart via LikeController',
      (tester) async {
    final repo = _FakeLikeRepo();
    await tester.pumpWidget(
      buildButton(
        repo: repo,
        auth: _StubAuthRepository(userId: 'u1'),
      ),
    );

    await tester.pump();
    await tester.tap(find.byKey(const Key('like_button_p1')));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(repo.toggleCalls, 1);
  });
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class _FakeLikeRepo implements LikeRepository {
  int toggleCalls = 0;
  final Map<String, Set<String>> _likes = {};

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
  }) async =>
      _likes[postId]?.contains(userId) ?? false;

  @override
  Future<int> likeCount(String postId) async =>
      _likes[postId]?.length ?? 0;

  @override
  Future<Map<String, int>> likeCountsForPosts(List<String> postIds) async =>
      {for (final id in postIds) id: _likes[id]?.length ?? 0};

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
  }) =>
      throw UnimplementedError();
}

class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository({required String userId})
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
