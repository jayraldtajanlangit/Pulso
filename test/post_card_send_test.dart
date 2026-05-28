import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/comment/comment_model.dart';
import 'package:pulso/comment/comment_repository.dart';
import 'package:pulso/follow/follow_repository.dart';
import 'package:pulso/like/like_repository.dart';
import 'package:pulso/message/conversation_model.dart';
import 'package:pulso/message/message_model.dart';
import 'package:pulso/message/message_repository.dart';
import 'package:pulso/notification/notification_model.dart';
import 'package:pulso/notification/notification_repository.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/comment_providers.dart';
import 'package:pulso/providers/follow_providers.dart';
import 'package:pulso/providers/like_providers.dart';
import 'package:pulso/providers/message_providers.dart';
import 'package:pulso/providers/notification_providers.dart';
import 'package:pulso/screens/conversation_screen.dart';
import 'package:pulso/widgets/post_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('send button shares the post to the selected user', (
    tester,
  ) async {
    final messageRepo = _FakeMessageRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          likeRepositoryProvider.overrideWithValue(_FakeLikeRepository()),
          commentRepositoryProvider.overrideWithValue(_FakeCommentRepository()),
          messageRepositoryProvider.overrideWithValue(messageRepo),
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: _post())),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('friend'), findsOneWidget);

    await tester.tap(find.text('friend'));
    await tester.pumpAndSettle();

    expect(messageRepo.findOrCreateCalls, 1);
    expect(messageRepo.sentSharedPostId, 'post-1');
    expect(messageRepo.sentRecipientConversationId, 'conv-1');
  });

  testWidgets('send button can include a message with the shared post', (
    tester,
  ) async {
    final messageRepo = _FakeMessageRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          likeRepositoryProvider.overrideWithValue(_FakeLikeRepository()),
          commentRepositoryProvider.overrideWithValue(_FakeCommentRepository()),
          messageRepositoryProvider.overrideWithValue(messageRepo),
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: _post())),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('sendMessageField')),
      'Check this out',
    );
    await tester.tap(find.text('friend'));
    await tester.pumpAndSettle();

    expect(messageRepo.sentBody, 'Check this out');
    expect(messageRepo.sentSharedPostId, 'post-1');
  });

  testWidgets('send button falls back when post with message is rejected', (
    tester,
  ) async {
    final messageRepo = _FakeMessageRepository(
      throwOnCombinedPostAndBody: true,
    );
    final notificationRepo = _FakeNotificationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          likeRepositoryProvider.overrideWithValue(_FakeLikeRepository()),
          commentRepositoryProvider.overrideWithValue(_FakeCommentRepository()),
          messageRepositoryProvider.overrideWithValue(messageRepo),
          notificationRepositoryProvider.overrideWithValue(notificationRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: _post())),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('sendMessageField')),
      'Check this out',
    );
    await tester.tap(find.text('friend'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't send post"), findsNothing);
    expect(find.byType(ConversationScreen), findsOneWidget);
    expect(messageRepo.sentMessages, hasLength(2));
    expect(messageRepo.sentMessages[0].body, isNull);
    expect(messageRepo.sentMessages[0].sharedPostId, 'post-1');
    expect(messageRepo.sentMessages[1].body, 'Check this out');
    expect(messageRepo.sentMessages[1].sharedPostId, isNull);
    expect(notificationRepo.insertCalls, 1);
    expect(notificationRepo.postId, 'post-1');
  });

  testWidgets('send button notifies the recipient about the shared post', (
    tester,
  ) async {
    final messageRepo = _FakeMessageRepository();
    final notificationRepo = _FakeNotificationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          likeRepositoryProvider.overrideWithValue(_FakeLikeRepository()),
          commentRepositoryProvider.overrideWithValue(_FakeCommentRepository()),
          messageRepositoryProvider.overrideWithValue(messageRepo),
          notificationRepositoryProvider.overrideWithValue(notificationRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: _post())),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('friend'));
    await tester.pumpAndSettle();

    expect(notificationRepo.recipientId, 'friend-id');
    expect(notificationRepo.actorId, 'current-user');
    expect(notificationRepo.type, 'message');
    expect(notificationRepo.postId, 'post-1');
  });

  testWidgets('send picker shows followers as recipients', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          followRepositoryProvider.overrideWithValue(
            _FakeFollowRepository(
              following: const [],
              followers: [
                _TestProfile(
                  id: 'follower-id',
                  username: 'follower',
                  displayName: 'Follower User',
                ),
              ],
            ),
          ),
          likeRepositoryProvider.overrideWithValue(_FakeLikeRepository()),
          commentRepositoryProvider.overrideWithValue(_FakeCommentRepository()),
          messageRepositoryProvider.overrideWithValue(_FakeMessageRepository()),
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: _post())),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('follower'), findsOneWidget);
    expect(find.text('No users found'), findsNothing);
  });

  testWidgets(
    'send button shows an error when the shared post cannot be sent',
    (tester) async {
      final messageRepo = _FakeMessageRepository(throwOnSend: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
            followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
            likeRepositoryProvider.overrideWithValue(_FakeLikeRepository()),
            commentRepositoryProvider.overrideWithValue(
              _FakeCommentRepository(),
            ),
            messageRepositoryProvider.overrideWithValue(messageRepo),
            notificationRepositoryProvider.overrideWithValue(
              _FakeNotificationRepository(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PostCard(post: _post())),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('friend'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't send post"), findsOneWidget);
      expect(find.byType(ConversationScreen), findsNothing);
    },
  );

  testWidgets('send button handles conversation creation failure', (
    tester,
  ) async {
    final messageRepo = _FakeMessageRepository(throwOnFindOrCreate: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          likeRepositoryProvider.overrideWithValue(_FakeLikeRepository()),
          commentRepositoryProvider.overrideWithValue(_FakeCommentRepository()),
          messageRepositoryProvider.overrideWithValue(messageRepo),
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: _post())),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.send_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('friend'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't send post"), findsOneWidget);
    expect(find.byType(ConversationScreen), findsNothing);
  });
}

PostModel _post() => PostModel(
  id: 'post-1',
  userId: 'author-1',
  caption: 'Share this',
  imageUrl: '',
  imageUrls: const [],
  authorUsername: 'author',
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

class _StubAuthRepository implements AuthRepository {
  final _session = const AppAuthSession(
    userId: 'current-user',
    email: 'current@example.com',
  );

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

class _FakeFollowRepository implements FollowRepository {
  _FakeFollowRepository({
    List<_TestProfile>? following,
    List<_TestProfile>? followers,
  }) : _following =
           following ??
           const [
             _TestProfile(
               id: 'friend-id',
               username: 'friend',
               displayName: 'Friend User',
             ),
           ],
       _followers = followers ?? const [];

  final List<_TestProfile> _following;
  final List<_TestProfile> _followers;

  @override
  Future<List<ProfileModel>> getFollowingProfiles(String userId) async =>
      _following.map((profile) => profile.toModel()).toList();

  @override
  Future<List<String>> getFollowingIds(String userId) async =>
      _following.map((profile) => profile.id).toList();

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
      _followers.map((profile) => profile.toModel()).toList();

  @override
  Future<int> getFollowingCount(String userId) async => _following.length;

  @override
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async => true;

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

class _TestProfile {
  const _TestProfile({
    required this.id,
    required this.username,
    required this.displayName,
  });

  final String id;
  final String username;
  final String displayName;

  ProfileModel toModel() => ProfileModel(
    id: id,
    username: username,
    displayName: displayName,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

class _FakeMessageRepository implements MessageRepository {
  _FakeMessageRepository({
    this.throwOnFindOrCreate = false,
    this.throwOnSend = false,
    this.throwOnCombinedPostAndBody = false,
  });

  final bool throwOnFindOrCreate;
  final bool throwOnSend;
  final bool throwOnCombinedPostAndBody;
  int findOrCreateCalls = 0;
  String? sentBody;
  String? sentSharedPostId;
  String? sentRecipientConversationId;
  final List<MessageModel> sentMessages = [];

  @override
  Future<String> findOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (throwOnFindOrCreate) throw Exception('conversation failed');
    findOrCreateCalls++;
    return 'conv-1';
  }

  @override
  Future<String?> findExistingConversation({
    required String currentUserId,
    required String otherUserId,
  }) async => null;

  @override
  Future<SentDirectMessage> sendDirectMessage({
    required String recipientUserId,
    String? body,
    String? sharedPostId,
  }) async => throw UnimplementedError();

  @override
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    String? body,
    String? sharedPostId,
  }) async {
    if (throwOnSend) throw Exception('send failed');
    if (throwOnCombinedPostAndBody && body != null && sharedPostId != null) {
      throw Exception('combined message rejected');
    }
    sentRecipientConversationId = conversationId;
    sentBody = body;
    sentSharedPostId = sharedPostId;
    final message = MessageModel(
      id: 'message-${sentMessages.length + 1}',
      conversationId: conversationId,
      senderId: senderId,
      body: body,
      sharedPostId: sharedPostId,
      sharedPostCaption: 'Share this',
      createdAt: DateTime(2024),
    );
    sentMessages.add(message);
    return message;
  }

  @override
  Future<List<ConversationModel>> fetchInbox(String userId) async => const [];

  @override
  Future<List<MessageModel>> fetchMessages(String conversationId) async =>
      const [];

  @override
  RealtimeChannel subscribeToMessages({
    required String conversationId,
    required void Function(MessageModel) onNew,
  }) => throw UnimplementedError();
}

class _FakeLikeRepository implements LikeRepository {
  @override
  Future<Set<String>> getLikedPostIdsForUser({
    required String userId,
    required List<String> postIds,
  }) async => const {};

  @override
  Future<bool> isLikedByUser({
    required String postId,
    required String userId,
  }) async => false;

  @override
  Future<int> likeCount(String postId) async => 0;

  @override
  Future<Map<String, int>> likeCountsForPosts(List<String> postIds) async => {
    for (final postId in postIds) postId: 0,
  };

  @override
  RealtimeChannel subscribeToLikes({
    required void Function(String postId) onLikeChanged,
  }) => throw UnimplementedError();

  @override
  Future<bool> toggleLike({
    required String postId,
    required String userId,
  }) async => true;
}

class _FakeCommentRepository implements CommentRepository {
  @override
  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String body,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteComment(String commentId) async {}

  @override
  Future<List<CommentModel>> fetchComments(String postId) async => const [];

  @override
  Future<int> getCommentCount(String postId) async => 0;

  @override
  Future<Map<String, int>> getCommentCountsForPosts(
    List<String> postIds,
  ) async => {for (final postId in postIds) postId: 0};

  @override
  RealtimeChannel subscribeToComments({
    required String postId,
    required void Function(CommentModel comment) onCommentAdded,
    void Function(String commentId)? onCommentDeleted,
  }) => throw UnimplementedError();
}

class _FakeNotificationRepository implements NotificationRepository {
  int insertCalls = 0;
  String? recipientId;
  String? actorId;
  String? type;
  String? postId;

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) async =>
      const [];

  @override
  Future<void> insertNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? postId,
  }) async {
    insertCalls++;
    this.recipientId = recipientId;
    this.actorId = actorId;
    this.type = type;
    this.postId = postId;
  }

  @override
  Future<void> markAllRead(String userId) async {}

  @override
  RealtimeChannel subscribe(
    String userId,
    void Function(NotificationModel) onNew,
  ) => throw UnimplementedError();
}
