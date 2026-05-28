import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/follow/follow_repository.dart';
import 'package:pulso/notification/notification_model.dart';
import 'package:pulso/notification/notification_repository.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/follow_providers.dart';
import 'package:pulso/providers/notification_providers.dart';
import 'package:pulso/screens/activity_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('activity screen loads and renders notifications', (
    tester,
  ) async {
    final repo = _FakeNotificationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          notificationRepositoryProvider.overrideWithValue(repo),
          followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
        ],
        child: const MaterialApp(home: ActivityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('liked your post', findRichText: true),
      findsOneWidget,
    );
    expect(repo.fetchCalls, 1);
    expect(repo.markAllReadCalls, 1);
  });

  testWidgets(
    'activity screen hides message-type notifications (they belong in the Messages tab)',
    (tester) async {
      final repo = _FakeNotificationRepository(
        notifications: [
          NotificationModel(
            id: 'n2',
            recipientId: 'me',
            actorId: 'actor',
            type: 'message',
            postId: 'post-1',
            read: false,
            createdAt: DateTime.now(),
            actorUsername: 'alice',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
            notificationRepositoryProvider.overrideWithValue(repo),
            followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          ],
          child: const MaterialApp(home: ActivityScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Message/shared-post events should NOT appear in the bell — they live
      // in the Messages tab instead.
      expect(
        find.textContaining('sent you a post', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('sent you a message', findRichText: true),
        findsNothing,
      );
    },
  );
}

class _StubAuthRepository implements AuthRepository {
  final _session = const AppAuthSession(userId: 'me', email: 'me@example.com');

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

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository({List<NotificationModel>? notifications})
    : _notifications = notifications;

  final List<NotificationModel>? _notifications;
  int fetchCalls = 0;
  int markAllReadCalls = 0;

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    fetchCalls++;
    if (_notifications != null) return _notifications;
    return [
      NotificationModel(
        id: 'n1',
        recipientId: userId,
        actorId: 'actor',
        type: 'like',
        postId: 'post-1',
        read: false,
        createdAt: DateTime.now(),
        actorUsername: 'alice',
      ),
    ];
  }

  @override
  Future<void> insertNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? postId,
    String? storyId,
  }) async {}

  @override
  Future<void> markAllRead(String userId) async {
    markAllReadCalls++;
  }

  @override
  RealtimeChannel subscribe(
    String userId,
    void Function(NotificationModel) onNew,
  ) => throw UnimplementedError();
}

class _FakeFollowRepository implements FollowRepository {
  @override
  Future<void> follow({
    required String followerId,
    required String followingId,
  }) async {}

  @override
  Future<int> getFollowerCount(String userId) async => 0;

  @override
  Future<List<String>> getFollowerIds(String userId) async => const [];

  @override
  Future<List<ProfileModel>> getFollowerProfiles(String userId) async =>
      const [];

  @override
  Future<int> getFollowingCount(String userId) async => 0;

  @override
  Future<List<String>> getFollowingIds(String userId) async => const [];

  @override
  Future<List<ProfileModel>> getFollowingProfiles(String userId) async =>
      const [];

  @override
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async => false;

  @override
  Future<bool> toggleFollow({
    required String followerId,
    required String followingId,
  }) async => true;

  @override
  Future<void> unfollow({
    required String followerId,
    required String followingId,
  }) async {}
}
