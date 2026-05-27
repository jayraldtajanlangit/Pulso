import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pulso/message/conversation_model.dart';
import 'package:pulso/message/message_model.dart';
import 'package:pulso/message/message_repository.dart';

class MockMessageRepository extends Mock implements MessageRepository {}

void main() {
  late MockMessageRepository repo;

  setUp(() => repo = MockMessageRepository());

  test('findOrCreateConversation returns a conversation id', () async {
    when(() => repo.findOrCreateConversation(
          currentUserId: any(named: 'currentUserId'),
          otherUserId: any(named: 'otherUserId'),
        )).thenAnswer((_) async => 'conv1');

    final id = await repo.findOrCreateConversation(
      currentUserId: 'u1',
      otherUserId: 'u2',
    );
    expect(id, 'conv1');
  });

  test('fetchInbox returns list of conversations', () async {
    when(() => repo.fetchInbox(any())).thenAnswer((_) async => []);

    final result = await repo.fetchInbox('u1');
    expect(result, isA<List<ConversationModel>>());
  });

  test('sendMessage returns a MessageModel', () async {
    final fakeMsg = MessageModel(
      id: 'm1',
      conversationId: 'conv1',
      senderId: 'u1',
      body: 'hi',
      createdAt: DateTime.now(),
    );
    when(() => repo.sendMessage(
          conversationId: any(named: 'conversationId'),
          senderId: any(named: 'senderId'),
          body: any(named: 'body'),
          sharedPostId: any(named: 'sharedPostId'),
        )).thenAnswer((_) async => fakeMsg);

    final msg = await repo.sendMessage(
      conversationId: 'conv1',
      senderId: 'u1',
      body: 'hi',
    );
    expect(msg.body, 'hi');
  });
}
