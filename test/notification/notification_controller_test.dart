import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pulso/notification/notification_controller.dart';
import 'package:pulso/notification/notification_model.dart';
import 'package:pulso/notification/notification_repository.dart';
import 'package:pulso/providers/notification_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

NotificationModel _fakeNotification({bool read = false}) =>
    NotificationModel(
      id: 'n1',
      recipientId: 'user1',
      actorId: 'actor1',
      type: 'like',
      read: read,
      createdAt: DateTime.now(),
    );

void main() {
  late MockNotificationRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockNotificationRepository();
    container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('initial state has empty list and zero unread', () {
    final state = container.read(notificationControllerProvider);
    expect(state.notifications, isEmpty);
    expect(state.unreadCount, 0);
    expect(state.isLoading, false);
  });

  test('load fills notifications and counts unread', () async {
    when(() => mockRepo.fetchNotifications('user1')).thenAnswer(
      (_) async => [_fakeNotification(read: false), _fakeNotification(read: true)],
    );
    when(() => mockRepo.subscribe(any(), any())).thenReturn(
      // Return a fake channel — just needs to not crash
      _FakeChannel(),
    );

    await container
        .read(notificationControllerProvider.notifier)
        .load('user1');

    final state = container.read(notificationControllerProvider);
    expect(state.notifications.length, 2);
    expect(state.unreadCount, 1);
  });

  test('markAllRead sets all notifications to read and resets unreadCount', () async {
    when(() => mockRepo.fetchNotifications('user1')).thenAnswer(
      (_) async => [_fakeNotification(read: false)],
    );
    when(() => mockRepo.subscribe(any(), any())).thenReturn(_FakeChannel());
    when(() => mockRepo.markAllRead('user1')).thenAnswer((_) async {});

    await container.read(notificationControllerProvider.notifier).load('user1');
    await container
        .read(notificationControllerProvider.notifier)
        .markAllRead('user1');

    final state = container.read(notificationControllerProvider);
    expect(state.unreadCount, 0);
    expect(state.notifications.every((n) => n.read), true);
  });
}

class _FakeChannel extends Fake implements RealtimeChannel {}
