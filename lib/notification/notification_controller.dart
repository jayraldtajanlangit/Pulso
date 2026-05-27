import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/notification_providers.dart';
import 'notification_model.dart';
import 'notification_repository.dart';

class NotificationState {
  const NotificationState({
    required this.notifications,
    required this.unreadCount,
    this.isLoading = false,
  });

  const NotificationState.initial()
      : notifications = const [],
        unreadCount = 0,
        isLoading = false;

  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationController extends Notifier<NotificationState> {
  RealtimeChannel? _channel;

  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  NotificationState build() {
    ref.onDispose(() {
      final ch = _channel;
      if (ch == null) return;
      try {
        Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
      _channel = null;
    });
    return const NotificationState.initial();
  }

  Future<void> load(String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      final notifications = await _repository.fetchNotifications(userId);
      final unreadCount = notifications.where((n) => !n.read).length;
      state = NotificationState(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
      _subscribe(userId);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markAllRead(String userId) async {
    await _repository.markAllRead(userId);
    state = state.copyWith(
      notifications:
          state.notifications.map((n) => n.copyWith(read: true)).toList(),
      unreadCount: 0,
    );
  }

  void _subscribe(String userId) {
    if (_channel != null) return;
    _channel = _repository.subscribe(userId, (notification) {
      state = state.copyWith(
        notifications: [notification, ...state.notifications],
        unreadCount: state.unreadCount + 1,
      );
    });
  }
}
