import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/message/conversation_model.dart';
import 'package:pulso/message/message_model.dart';

void main() {
  group('ConversationModel.fromMap', () {
    test('parses all fields with joined last message and other participant', () {
      final map = {
        'id': 'conv1',
        'last_message_at': '2026-05-28T00:00:00.000Z',
        'created_at': '2026-05-27T00:00:00.000Z',
        'other_user': {
          'id': 'user2',
          'username': 'maria',
          'avatar_url': 'https://example.com/av.jpg',
        },
        'last_message_body': 'Hey!',
        'last_message_is_own': false,
        'unread_count': 2,
      };

      final model = ConversationModel.fromMap(map);

      expect(model.id, 'conv1');
      expect(model.otherUserId, 'user2');
      expect(model.otherUsername, 'maria');
      expect(model.lastMessageBody, 'Hey!');
      expect(model.unreadCount, 2);
    });
  });

  group('MessageModel.fromMap', () {
    test('parses text message', () {
      final map = {
        'id': 'msg1',
        'conversation_id': 'conv1',
        'sender_id': 'user1',
        'body': 'Hello!',
        'shared_post_id': null,
        'created_at': '2026-05-28T00:00:00.000Z',
        'sender': {'username': 'juan', 'avatar_url': null},
        'shared_post': null,
      };

      final model = MessageModel.fromMap(map);

      expect(model.id, 'msg1');
      expect(model.body, 'Hello!');
      expect(model.sharedPostId, isNull);
      expect(model.senderUsername, 'juan');
    });

    test('parses shared post message', () {
      final map = {
        'id': 'msg2',
        'conversation_id': 'conv1',
        'sender_id': 'user1',
        'body': null,
        'shared_post_id': 'post1',
        'created_at': '2026-05-28T00:00:00.000Z',
        'sender': {'username': 'juan', 'avatar_url': null},
        'shared_post': {
          'id': 'post1',
          'image_url': 'https://example.com/img.jpg',
          'caption': 'Check this out',
        },
      };

      final model = MessageModel.fromMap(map);

      expect(model.sharedPostId, 'post1');
      expect(model.sharedPostImageUrl, 'https://example.com/img.jpg');
      expect(model.body, isNull);
    });
  });
}
