import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../message/conversation_model.dart';
import '../profile/profile_model.dart';
import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/message_providers.dart';
import '../widgets/profile_avatar.dart';
import 'conversation_screen.dart';
import 'new_message_screen.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  bool _didInit = false;
  bool _isLoadingSuggestions = false;
  List<ProfileModel> _suggestedProfiles = [];

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
    await Future.wait([
      ref.read(messageControllerProvider.notifier).loadInbox(userId),
      _loadSuggestions(userId),
    ]);
  }

  Future<void> _loadSuggestions(String userId) async {
    if (mounted) setState(() => _isLoadingSuggestions = true);
    try {
      final followRepository = ref.read(followRepositoryProvider);
      final results = await Future.wait([
        followRepository.getFollowingProfiles(userId),
        followRepository.getFollowerProfiles(userId),
      ]);
      final suggestions = _dedupeProfiles([...results[0], ...results[1]]);
      if (!mounted) return;
      setState(() {
        _suggestedProfiles = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSuggestions = false);
    }
  }

  List<ProfileModel> _dedupeProfiles(List<ProfileModel> profiles) {
    final byId = <String, ProfileModel>{};
    for (final profile in profiles) {
      byId.putIfAbsent(profile.id, () => profile);
    }
    return byId.values.toList();
  }

  Future<void> _openConversationWith(ProfileModel profile) async {
    // Don't create the conversation up-front — let ConversationScreen resolve
    // an existing one (if any) and only create on the first send. This avoids
    // empty "phantom" conversations when the user opens and backs out.
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          otherUserId: profile.id,
          otherUsername: profile.username ?? profile.displayName ?? '?',
          otherAvatarUrl: profile.avatarUrl,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openNewMessage() async {
    final result = await Navigator.push<ProfileModel>(
      context,
      MaterialPageRoute(builder: (_) => const NewMessageScreen()),
    );
    if (result != null && mounted) {
      await _openConversationWith(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageControllerProvider);
    final conversationUserIds = state.inbox.map((c) => c.otherUserId).toSet();
    final suggestions = _suggestedProfiles
        .where((p) => !conversationUserIds.contains(p.id))
        .toList();
    final isInitialLoading =
        state.isLoadingInbox && state.inbox.isEmpty && _isLoadingSuggestions;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, size: 24),
            tooltip: 'New message',
            onPressed: _openNewMessage,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : state.inbox.isEmpty && suggestions.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: Color(0xFFD1D5DB),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your messages',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Send a message to a friend',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _openNewMessage,
                      child: const Text('Send message'),
                    ),
                  ],
                ),
              )
            : ListView(
                children: [
                  for (final conversation in state.inbox)
                    _ConversationTile(conversation: conversation),
                  if (suggestions.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Text(
                        'Suggested',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    for (final profile in suggestions)
                      _SuggestedProfileTile(
                        profile: profile,
                        onTap: () => _openConversationWith(profile),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SuggestedProfileTile extends StatelessWidget {
  const _SuggestedProfileTile({required this.profile, required this.onTap});

  final ProfileModel profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = profile.username ?? profile.displayName ?? '?';
    final subtitle = (profile.displayName != null &&
            profile.displayName != profile.username)
        ? profile.displayName!
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ProfileAvatar(avatarUrl: profile.avatarUrl, displayName: name, radius: 26),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))
          : null,
      trailing: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Message',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      onTap: onTap,
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
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final name = conversation.otherUsername ?? '?';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: conversation.id,
            otherUserId: conversation.otherUserId,
            otherUsername: name,
            otherAvatarUrl: conversation.otherAvatarUrl,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ProfileAvatar(
              avatarUrl: conversation.otherAvatarUrl,
              displayName: name,
              radius: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (conversation.lastMessageBody != null)
                    Text(
                      '${conversation.lastMessageIsOwn ? 'You: ' : ''}${conversation.lastMessageBody}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? const Color(0xFF111827)
                            : const Color(0xFF9CA3AF),
                        fontSize: 13,
                        fontWeight: hasUnread
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _relativeTime(),
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }
}
