import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/notification/notification_model.dart';

void main() {
  group('NotificationModel.fromMap', () {
    test('parses all fields with joined actor and post', () {
      final map = {
        'id': 'n1',
        'recipient_id': 'r1',
        'actor_id': 'a1',
        'type': 'like',
        'post_id': 'p1',
        'read': false,
        'created_at': '2026-01-01T00:00:00.000Z',
        'actor': {'username': 'juan', 'avatar_url': 'https://example.com/av.jpg'},
        'post': {'image_url': 'https://example.com/img.jpg'},
      };

      final model = NotificationModel.fromMap(map);

      expect(model.id, 'n1');
      expect(model.recipientId, 'r1');
      expect(model.actorId, 'a1');
      expect(model.type, 'like');
      expect(model.postId, 'p1');
      expect(model.read, false);
      expect(model.actorUsername, 'juan');
      expect(model.actorAvatarUrl, 'https://example.com/av.jpg');
      expect(model.postImageUrl, 'https://example.com/img.jpg');
    });

    test('handles null post and actor joins gracefully', () {
      final map = {
        'id': 'n2',
        'recipient_id': 'r1',
        'actor_id': 'a1',
        'type': 'follow',
        'post_id': null,
        'read': true,
        'created_at': '2026-01-01T00:00:00.000Z',
        'actor': null,
        'post': null,
      };

      final model = NotificationModel.fromMap(map);

      expect(model.postId, isNull);
      expect(model.actorUsername, isNull);
      expect(model.postImageUrl, isNull);
      expect(model.read, true);
    });

    test('copyWith only changes read field', () {
      final original = NotificationModel.fromMap({
        'id': 'n1',
        'recipient_id': 'r1',
        'actor_id': 'a1',
        'type': 'like',
        'post_id': null,
        'read': false,
        'created_at': '2026-01-01T00:00:00.000Z',
        'actor': null,
        'post': null,
      });

      final updated = original.copyWith(read: true);

      expect(updated.read, true);
      expect(updated.id, original.id);
      expect(updated.type, original.type);
    });
  });
}
