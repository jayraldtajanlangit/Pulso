import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationModel>> fetchNotifications(String userId);
  Future<void> markAllRead(String userId);

  /// Insert a new notification row.
  ///
  /// For story reactions, pass [storyId] (and not [postId]).
  /// For post likes / comments, pass [postId].
  /// For follow events, pass neither.
  Future<void> insertNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? postId,
    String? storyId,
  });

  RealtimeChannel subscribe(
    String userId,
    void Function(NotificationModel) onNew,
  );
}

class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, actor:profiles!actor_id(username, avatar_url), '
      'post:posts!post_id(image_url), story:stories!story_id(image_url)';

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select(_select)
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((row) => NotificationModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('recipient_id', userId)
        .eq('read', false);
  }

  @override
  Future<void> insertNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? postId,
    String? storyId,
  }) async {
    if (recipientId == actorId) return; // never notify yourself
    await _client.from('notifications').insert({
      'recipient_id': recipientId,
      'actor_id': actorId,
      'type': type,
      if (postId != null) 'post_id': postId,
      if (storyId != null) 'story_id': storyId,
    });
  }

  @override
  RealtimeChannel subscribe(
    String userId,
    void Function(NotificationModel) onNew,
  ) {
    return _client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) async {
            final id = payload.newRecord['id'] as String?;
            if (id == null) return;
            final row = await _client
                .from('notifications')
                .select(_select)
                .eq('id', id)
                .maybeSingle();
            if (row != null) onNew(NotificationModel.fromMap(row));
          },
        )
        .subscribe();
  }
}
