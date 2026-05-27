import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversation_model.dart';
import 'message_model.dart';

abstract class MessageRepository {
  Future<String> findOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
  });

  Future<List<ConversationModel>> fetchInbox(String userId);

  Future<List<MessageModel>> fetchMessages(String conversationId);

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    String? body,
    String? sharedPostId,
  });

  RealtimeChannel subscribeToMessages({
    required String conversationId,
    required void Function(MessageModel) onNew,
  });
}

class SupabaseMessageRepository implements MessageRepository {
  const SupabaseMessageRepository(this._client);

  final SupabaseClient _client;

  static const _messageSelect =
      '*, sender:profiles!sender_id(username, avatar_url), '
      'shared_post:posts!shared_post_id(id, image_url, caption)';

  @override
  Future<String> findOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final existing = await _client
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', currentUserId);

    final myConvIds = (existing as List)
        .map((r) => (r as Map<String, dynamic>)['conversation_id'] as String)
        .toList();

    if (myConvIds.isNotEmpty) {
      final shared = await _client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', otherUserId)
          .inFilter('conversation_id', myConvIds)
          .limit(1)
          .maybeSingle();

      if (shared != null) {
        return shared['conversation_id'] as String;
      }
    }

    final conv = await _client
        .from('conversations')
        .insert({'last_message_at': DateTime.now().toIso8601String()})
        .select('id')
        .single();

    final convId = conv['id'] as String;

    await _client.from('conversation_participants').insert([
      {'conversation_id': convId, 'user_id': currentUserId},
      {'conversation_id': convId, 'user_id': otherUserId},
    ]);

    return convId;
  }

  @override
  Future<List<ConversationModel>> fetchInbox(String userId) async {
    final participations = await _client
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', userId);

    final convIds = (participations as List)
        .map((r) => (r as Map<String, dynamic>)['conversation_id'] as String)
        .toList();

    if (convIds.isEmpty) return [];

    final conversations = await _client
        .from('conversations')
        .select('*')
        .inFilter('id', convIds)
        .order('last_message_at', ascending: false);

    final results = <ConversationModel>[];
    for (final conv in conversations as List) {
      final convMap = conv as Map<String, dynamic>;
      final convId = convMap['id'] as String;

      final otherParticipant = await _client
          .from('conversation_participants')
          .select('user_id, profiles!user_id(id, username, avatar_url)')
          .eq('conversation_id', convId)
          .neq('user_id', userId)
          .limit(1)
          .maybeSingle();

      final lastMsg = await _client
          .from('messages')
          .select('body, sender_id, shared_post_id')
          .eq('conversation_id', convId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final other = otherParticipant?['profiles'] as Map<String, dynamic>?;
      final lastMsgMap = lastMsg;

      String? lastBody;
      bool isOwn = false;
      if (lastMsgMap != null) {
        final postId = lastMsgMap['shared_post_id'] as String?;
        lastBody =
            postId != null ? 'Sent a post' : lastMsgMap['body'] as String?;
        isOwn = lastMsgMap['sender_id'] == userId;
      }

      results.add(ConversationModel.fromMap({
        ...convMap,
        'other_user': other,
        'last_message_body': lastBody,
        'last_message_is_own': isOwn,
        'unread_count': 0,
      }));
    }
    return results;
  }

  @override
  Future<List<MessageModel>> fetchMessages(String conversationId) async {
    final response = await _client
        .from('messages')
        .select(_messageSelect)
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((row) => MessageModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    String? body,
    String? sharedPostId,
  }) async {
    final response = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'body': body,
          'shared_post_id': sharedPostId,
        })
        .select(_messageSelect)
        .single();

    await _client
        .from('conversations')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);

    return MessageModel.fromMap(response);
  }

  @override
  RealtimeChannel subscribeToMessages({
    required String conversationId,
    required void Function(MessageModel) onNew,
  }) {
    return _client
        .channel('messages_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final id = payload.newRecord['id'] as String?;
            if (id == null) return;
            final row = await _client
                .from('messages')
                .select(_messageSelect)
                .eq('id', id)
                .maybeSingle();
            if (row != null) onNew(MessageModel.fromMap(row));
          },
        )
        .subscribe();
  }
}
