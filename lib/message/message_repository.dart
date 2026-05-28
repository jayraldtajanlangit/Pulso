import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversation_model.dart';
import 'message_model.dart';

abstract class MessageRepository {
  Future<String> findOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
  });

  /// Returns the existing conversation id between the two users, or `null`
  /// if no conversation exists yet. Never creates one.
  Future<String?> findExistingConversation({
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

  /// Atomically finds-or-creates a 1:1 conversation with [recipientUserId]
  /// and inserts a message in a single server-side transaction. Returns the
  /// resolved conversation id plus the inserted message.
  ///
  /// Prefer this over the [findOrCreateConversation] + [sendMessage] pair
  /// when starting a new conversation — it sidesteps the multi-HTTP-request
  /// RLS/timing fragility (see `send_direct_message` SQL function).
  Future<SentDirectMessage> sendDirectMessage({
    required String recipientUserId,
    String? body,
    String? sharedPostId,
  });

  RealtimeChannel subscribeToMessages({
    required String conversationId,
    required void Function(MessageModel) onNew,
  });
}

class SentDirectMessage {
  const SentDirectMessage({required this.conversationId, required this.message});

  final String conversationId;
  final MessageModel message;
}

class SupabaseMessageRepository implements MessageRepository {
  const SupabaseMessageRepository(this._client);

  final SupabaseClient _client;

  static const _messageSelect =
      '*, sender:profiles!sender_id(username, display_name, avatar_url), '
      'shared_post:posts!shared_post_id(id, image_url, caption)';

  @override
  Future<String?> findExistingConversation({
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

    if (myConvIds.isEmpty) return null;

    final sharedRows = await _client
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', otherUserId)
        .inFilter('conversation_id', myConvIds);

    final sharedConvIds = (sharedRows as List)
        .map((r) => (r as Map<String, dynamic>)['conversation_id'] as String)
        .toList();

    if (sharedConvIds.isEmpty) return null;
    if (sharedConvIds.length == 1) return sharedConvIds.single;

    final latestWithMessages =
        await _latestConversationWithMessages(sharedConvIds);
    if (latestWithMessages != null) return latestWithMessages;

    final latest = await _client
        .from('conversations')
        .select('id')
        .inFilter('id', sharedConvIds)
        .order('last_message_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (latest != null) return latest['id'] as String;
    return sharedConvIds.first;
  }

  @override
  Future<String> findOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final existing = await findExistingConversation(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
    if (existing != null) return existing;

    final convId = _newUuidV4();
    await _client.from('conversations').insert({
      'id': convId,
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _client.from('conversation_participants').insert([
      {'conversation_id': convId, 'user_id': currentUserId},
      {'conversation_id': convId, 'user_id': otherUserId},
    ]);

    return convId;
  }

  Future<String?> _latestConversationWithMessages(
    List<String> conversationIds,
  ) async {
    try {
      final latestMessage = await _client
          .from('messages')
          .select('conversation_id')
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return latestMessage?['conversation_id'] as String?;
    } catch (_) {
      return null;
    }
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
    final seenOtherUserIds = <String>{};

    for (final conv in conversations as List) {
      final convMap = conv as Map<String, dynamic>;
      final convId = convMap['id'] as String;

      final lastMsg = await _client
          .from('messages')
          .select('body, sender_id, shared_post_id')
          .eq('conversation_id', convId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastMsg == null) continue;

      // Fetch other participant's user_id without an embedded join
      // (embedded joins via `profiles!user_id` can silently fail in PostgREST)
      final otherParticipantRow = await _client
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', convId)
          .neq('user_id', userId)
          .limit(1)
          .maybeSingle();

      final otherUserId = otherParticipantRow?['user_id'] as String?;
      if (otherUserId == null || otherUserId.isEmpty) continue;

      // Deduplicate: only keep the most-recent conversation per other user
      if (!seenOtherUserIds.add(otherUserId)) continue;

      // Direct profile lookup
      final profileData = await _client
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .eq('id', otherUserId)
          .maybeSingle();

      final other = profileData ?? {'id': otherUserId};

      final postId = lastMsg['shared_post_id'] as String?;
      final lastBody =
          postId != null ? 'Sent a post' : lastMsg['body'] as String?;
      final isOwn = lastMsg['sender_id'] == userId;

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
  Future<SentDirectMessage> sendDirectMessage({
    required String recipientUserId,
    String? body,
    String? sharedPostId,
  }) async {
    final result = await _client.rpc(
      'send_direct_message',
      params: {
        'recipient_id': recipientUserId,
        'message_body': body,
        'shared_post': sharedPostId,
      },
    );

    if (result is! Map) {
      throw StateError('send_direct_message returned ${result.runtimeType}');
    }

    final map = Map<String, dynamic>.from(result);
    final conversationId = map['conversation_id'] as String?;
    final messageMap = map['message'];

    if (conversationId == null || messageMap is! Map) {
      throw StateError('send_direct_message returned malformed payload: $map');
    }

    return SentDirectMessage(
      conversationId: conversationId,
      message: MessageModel.fromMap(Map<String, dynamic>.from(messageMap)),
    );
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

final math.Random _uuidRandom = _createUuidRandom();

math.Random _createUuidRandom() {
  try {
    return math.Random.secure();
  } on UnsupportedError {
    return math.Random();
  }
}

String _newUuidV4() {
  final bytes = List<int>.generate(16, (_) => _uuidRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String byte(int index) => bytes[index].toRadixString(16).padLeft(2, '0');

  return '${byte(0)}${byte(1)}${byte(2)}${byte(3)}-'
      '${byte(4)}${byte(5)}-'
      '${byte(6)}${byte(7)}-'
      '${byte(8)}${byte(9)}-'
      '${byte(10)}${byte(11)}${byte(12)}${byte(13)}${byte(14)}${byte(15)}';
}
