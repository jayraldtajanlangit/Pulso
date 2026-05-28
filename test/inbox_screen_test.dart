import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/follow/follow_repository.dart';
import 'package:pulso/message/conversation_model.dart';
import 'package:pulso/message/message_model.dart';
import 'package:pulso/message/message_repository.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/follow_providers.dart';
import 'package:pulso/providers/message_providers.dart';
import 'package:pulso/screens/conversation_screen.dart';
import 'package:pulso/screens/inbox_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('messages screen shows followers as chat suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
          messageRepositoryProvider.overrideWithValue(_FakeMessageRepository()),
          followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
        ],
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('follower'), findsOneWidget);
    expect(find.text('Follower User'), findsOneWidget);
    expect(find.text('No messages yet'), findsNothing);
  });

  testWidgets(
    'tapping a follower suggestion opens a conversation without creating one',
    (tester) async {
      final messageRepo = _FakeMessageRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
            messageRepositoryProvider.overrideWithValue(messageRepo),
            followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          ],
          child: const MaterialApp(home: InboxScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('follower'));
      await tester.pumpAndSettle();

      // Opening the chat should not create a conversation yet — only look up.
      expect(messageRepo.findOrCreateCalls, 0);
      expect(messageRepo.findExistingCalls, 1);
      expect(find.byType(ConversationScreen), findsOneWidget);
    },
  );

  testWidgets(
    'sending the first message goes through the atomic RPC, not findOrCreate',
    (tester) async {
      final messageRepo = _FakeMessageRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
            messageRepositoryProvider.overrideWithValue(messageRepo),
            followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          ],
          child: const MaterialApp(home: InboxScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('follower'));
      await tester.pumpAndSettle();
      expect(messageRepo.findOrCreateCalls, 0);
      expect(messageRepo.sendDirectCalls, 0);

      await tester.enterText(find.byType(TextField), 'first message');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // The first send must use the atomic RPC (sendDirectMessage), NOT the
      // fragile findOrCreate + sendMessage pair.
      expect(messageRepo.sendDirectCalls, 1);
      expect(messageRepo.findOrCreateCalls, 0);
    },
  );

  testWidgets(
    'sent message renders in the chat UI immediately after sending',
    (tester) async {
      final messageRepo = _FakeMessageRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
            messageRepositoryProvider.overrideWithValue(messageRepo),
            followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          ],
          child: const MaterialApp(home: InboxScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('follower'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hello there');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // The sent message must be visible in the chat — this is the bug under
      // investigation. If this fails, the conditional ref.watch is not picking
      // up the state change after _conversationId is set.
      expect(find.text('hello there'), findsOneWidget);
    },
  );

  testWidgets(
    'message sent to a suggestion appears in the inbox after returning',
    (tester) async {
      final messageRepo = _FakeMessageRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
            messageRepositoryProvider.overrideWithValue(messageRepo),
            followRepositoryProvider.overrideWithValue(_FakeFollowRepository()),
          ],
          child: const MaterialApp(home: InboxScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('follower'), findsOneWidget);
      expect(find.text('Follower User'), findsOneWidget);

      await tester.tap(find.text('follower'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello from inbox');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(messageRepo.fetchInboxCalls, greaterThan(1));
      expect(find.text('follower'), findsOneWidget);
      expect(find.text('Follower User'), findsNothing);
      expect(find.text('You: Hello from inbox'), findsOneWidget);
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

class _FakeMessageRepository implements MessageRepository {
  int findOrCreateCalls = 0;
  int findExistingCalls = 0;
  int fetchInboxCalls = 0;
  int sendDirectCalls = 0;
  String? _lastMessageBody;

  @override
  Future<String> findOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    findOrCreateCalls++;
    return 'conv-follower';
  }

  @override
  Future<String?> findExistingConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    findExistingCalls++;
    // A new conversation that hasn't been used yet has no existing record.
    return _lastMessageBody == null ? null : 'conv-follower';
  }

  @override
  Future<SentDirectMessage> sendDirectMessage({
    required String recipientUserId,
    String? body,
    String? sharedPostId,
  }) async {
    sendDirectCalls++;
    _lastMessageBody = body;
    return SentDirectMessage(
      conversationId: 'conv-follower',
      message: MessageModel(
        id: 'm-direct-$sendDirectCalls',
        conversationId: 'conv-follower',
        senderId: 'me',
        body: body,
        sharedPostId: sharedPostId,
        createdAt: DateTime(2024, 1, 2),
      ),
    );
  }

  @override
  Future<List<ConversationModel>> fetchInbox(String userId) async {
    fetchInboxCalls++;
    final lastMessageBody = _lastMessageBody;
    if (lastMessageBody == null) return const [];
    return [
      ConversationModel(
        id: 'conv-follower',
        otherUserId: 'follower-id',
        otherUsername: 'follower',
        lastMessageBody: lastMessageBody,
        lastMessageIsOwn: true,
        lastMessageAt: DateTime(2024, 1, 2),
        createdAt: DateTime(2024),
      ),
    ];
  }

  @override
  Future<List<MessageModel>> fetchMessages(String conversationId) async =>
      const [];

  @override
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    String? body,
    String? sharedPostId,
  }) async {
    _lastMessageBody = body;
    return MessageModel(
      id: 'm1',
      conversationId: conversationId,
      senderId: senderId,
      body: body,
      sharedPostId: sharedPostId,
      createdAt: DateTime(2024),
    );
  }

  @override
  RealtimeChannel subscribeToMessages({
    required String conversationId,
    required void Function(MessageModel) onNew,
  }) => throw UnimplementedError();
}

class _FakeFollowRepository implements FollowRepository {
  final _follower = ProfileModel(
    id: 'follower-id',
    username: 'follower',
    displayName: 'Follower User',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  @override
  Future<List<ProfileModel>> getFollowerProfiles(String userId) async => [
    _follower,
  ];

  @override
  Future<List<ProfileModel>> getFollowingProfiles(String userId) async =>
      const [];

  @override
  Future<List<String>> getFollowerIds(String userId) async => ['follower-id'];

  @override
  Future<List<String>> getFollowingIds(String userId) async => const [];

  @override
  Future<void> follow({
    required String followerId,
    required String followingId,
  }) async {}

  @override
  Future<int> getFollowerCount(String userId) async => 1;

  @override
  Future<int> getFollowingCount(String userId) async => 0;

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
