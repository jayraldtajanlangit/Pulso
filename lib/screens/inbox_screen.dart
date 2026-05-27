import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../message/conversation_model.dart';
import '../providers/auth_providers.dart';
import '../providers/message_providers.dart';
import '../widgets/profile_avatar.dart';
import 'conversation_screen.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;
    await ref.read(messageControllerProvider.notifier).loadInbox(userId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: state.isLoadingInbox && state.inbox.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.inbox.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.inbox.length,
                    itemBuilder: (context, i) =>
                        _ConversationTile(conversation: state.inbox[i]),
                  ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final ConversationModel conversation;

  String _relativeTime() {
    final diff = DateTime.now().difference(conversation.lastMessageAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ProfileAvatar(
        avatarUrl: conversation.otherAvatarUrl,
        displayName: conversation.otherUsername ?? '?',
        radius: 24,
      ),
      title: Text(
        conversation.otherUsername ?? '?',
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: conversation.lastMessageBody != null
          ? Text(
              '${conversation.lastMessageIsOwn ? 'You: ' : ''}${conversation.lastMessageBody}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasUnread
                    ? const Color(0xFF374151)
                    : const Color(0xFF9CA3AF),
                fontSize: 12,
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _relativeTime(),
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
          ),
          if (hasUnread) ...[
            const SizedBox(width: 6),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: conversation.id,
            otherUserId: conversation.otherUserId,
            otherUsername: conversation.otherUsername ?? '?',
            otherAvatarUrl: conversation.otherAvatarUrl,
          ),
        ),
      ),
    );
  }
}
