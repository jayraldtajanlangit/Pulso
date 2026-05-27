import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/message_providers.dart';
import '../providers/notification_providers.dart';
import 'conversation_model.dart';
import 'message_model.dart';
import 'message_repository.dart';

class MessageState {
  const MessageState({
    required this.inbox,
    required this.messages,
    this.isLoadingInbox = false,
    this.isLoadingMessages = false,
    this.isSending = false,
  });

  const MessageState.initial()
      : inbox = const [],
        messages = const {},
        isLoadingInbox = false,
        isLoadingMessages = false,
        isSending = false;

  final List<ConversationModel> inbox;
  final Map<String, List<MessageModel>> messages;
  final bool isLoadingInbox;
  final bool isLoadingMessages;
  final bool isSending;

  List<MessageModel> messagesFor(String conversationId) =>
      messages[conversationId] ?? const [];

  MessageState copyWith({
    List<ConversationModel>? inbox,
    Map<String, List<MessageModel>>? messages,
    bool? isLoadingInbox,
    bool? isLoadingMessages,
    bool? isSending,
  }) {
    return MessageState(
      inbox: inbox ?? this.inbox,
      messages: messages ?? this.messages,
      isLoadingInbox: isLoadingInbox ?? this.isLoadingInbox,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSending: isSending ?? this.isSending,
    );
  }
}

class MessageController extends Notifier<MessageState> {
  final Map<String, RealtimeChannel> _channels = {};

  MessageRepository get _repository => ref.read(messageRepositoryProvider);

  @override
  MessageState build() {
    ref.onDispose(() {
      if (_channels.isEmpty) return;
      try {
        final client = Supabase.instance.client;
        for (final ch in _channels.values) {
          client.removeChannel(ch);
        }
      } catch (_) {}
      _channels.clear();
    });
    return const MessageState.initial();
  }

  Future<void> loadInbox(String userId) async {
    state = state.copyWith(isLoadingInbox: true);
    try {
      final inbox = await _repository.fetchInbox(userId);
      state = state.copyWith(inbox: inbox, isLoadingInbox: false);
    } catch (_) {
      state = state.copyWith(isLoadingInbox: false);
    }
  }

  Future<void> loadMessages(String conversationId) async {
    state = state.copyWith(isLoadingMessages: true);
    try {
      final msgs = await _repository.fetchMessages(conversationId);
      final updated = Map<String, List<MessageModel>>.from(state.messages);
      updated[conversationId] = msgs;
      state = state.copyWith(messages: updated, isLoadingMessages: false);
      _ensureSubscription(conversationId);
    } catch (_) {
      state = state.copyWith(isLoadingMessages: false);
    }
  }

  Future<String> findOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
  }) {
    return _repository.findOrCreateConversation(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String recipientId,
    String? body,
    String? sharedPostId,
  }) async {
    state = state.copyWith(isSending: true);
    try {
      final msg = await _repository.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        body: body,
        sharedPostId: sharedPostId,
      );
      final updated = Map<String, List<MessageModel>>.from(state.messages);
      final current = updated[conversationId] ?? [];
      if (!current.any((m) => m.id == msg.id)) {
        updated[conversationId] = [...current, msg];
      }
      state = state.copyWith(messages: updated, isSending: false);

      try {
        await ref.read(notificationRepositoryProvider).insertNotification(
              recipientId: recipientId,
              actorId: senderId,
              type: 'message',
            );
      } catch (_) {}
    } catch (_) {
      state = state.copyWith(isSending: false);
    }
  }

  void _ensureSubscription(String conversationId) {
    if (_channels.containsKey(conversationId)) return;
    _channels[conversationId] = _repository.subscribeToMessages(
      conversationId: conversationId,
      onNew: (msg) {
        final updated = Map<String, List<MessageModel>>.from(state.messages);
        final current = updated[conversationId] ?? [];
        if (current.any((m) => m.id == msg.id)) return;
        updated[conversationId] = [...current, msg];
        state = state.copyWith(messages: updated);
      },
    );
  }
}
