import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pulso/notification/notification_model.dart';
import 'package:pulso/notification/notification_repository.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  group('NotificationRepository contract', () {
    late MockNotificationRepository repo;

    setUp(() {
      repo = MockNotificationRepository();
    });

    test('fetchNotifications returns a list', () async {
      when(() => repo.fetchNotifications('user1'))
          .thenAnswer((_) async => []);

      final result = await repo.fetchNotifications('user1');
      expect(result, isA<List<NotificationModel>>());
    });

    test('markAllRead completes without error', () async {
      when(() => repo.markAllRead('user1')).thenAnswer((_) async {});

      await expectLater(repo.markAllRead('user1'), completes);
    });

    test('insertNotification completes without error', () async {
      when(() => repo.insertNotification(
            recipientId: any(named: 'recipientId'),
            actorId: any(named: 'actorId'),
            type: any(named: 'type'),
            postId: any(named: 'postId'),
          )).thenAnswer((_) async {});

      await expectLater(
        repo.insertNotification(
          recipientId: 'r1',
          actorId: 'a1',
          type: 'like',
          postId: 'p1',
        ),
        completes,
      );
    });
  });
}
