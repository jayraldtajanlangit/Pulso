import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../message/message_model.dart';
import '../providers/auth_providers.dart';
import '../providers/message_providers.dart';
import '../widgets/profile_avatar.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    this.conversationId,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
  });

  /// May be null when opening a conversation that hasn't been created yet.
  /// In that case the screen will resolve any existing conversation on init,
  /// and create one lazily when the user sends their first message.
  final String? conversationId;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;

  @override
  ConsumerState<ConversationScreen> createState() =>
      _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasText = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _inputController.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = _conversationId;
      if (id != null) {
        await ref.read(messageControllerProvider.notifier).loadMessages(id);
      } else {
        await _resolveExistingConversation();
      }
    });
  }

  Future<void> _resolveExistingConversation() async {
    final currentUserId = ref.read(authControllerProvider).session?.userId;
    if (currentUserId == null) return;

    final existing = await ref
        .read(messageControllerProvider.notifier)
        .findExistingConversation(
          currentUserId: currentUserId,
          otherUserId: widget.otherUserId,
        );
    if (!mounted || existing == null) return;
    setState(() => _conversationId = existing);
    await ref.read(messageControllerProvider.notifier).loadMessages(existing);
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final currentUserId = ref.read(authControllerProvider).session?.userId;
    if (currentUserId == null) return;

    // Clear the input optimistically; we'll restore it if sending fails so
    // the user can retry without re-typing.
    _inputController.clear();
    setState(() => _hasText = false);

    final convId = _conversationId;
    final controller = ref.read(messageControllerProvider.notifier);

    try {
      if (convId == null) {
        // No conversation yet — use the atomic RPC that creates the
        // conversation AND inserts the message in a single transaction.
        final result = await controller.sendDirectMessage(
          recipientUserId: widget.otherUserId,
          senderId: currentUserId,
          body: text,
        );
        if (!mounted) return;
        setState(() => _conversationId = result.conversationId);
      } else {
        final ok = await controller.sendMessage(
          conversationId: convId,
          senderId: currentUserId,
          recipientId: widget.otherUserId,
          body: text,
        );
        if (!ok) throw StateError('sendMessage returned false');
      }
    } catch (e) {
      if (!mounted) return;
      // Restore the text and tell the user — the previous behaviour silently
      // dropped the message, which made the whole feature look broken.
      _inputController.text = text;
      setState(() => _hasText = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't send message: $e")),
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.session?.userId));
    final convId = _conversationId;
    final List<MessageModel> messages = convId == null
        ? const <MessageModel>[]
        : ref.watch(
            messageControllerProvider.select((s) => s.messagesFor(convId)),
          );
    final isSending =
        ref.watch(messageControllerProvider.select((s) => s.isSending));
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 40,
        title: Row(
          children: [
            ProfileAvatar(
              avatarUrl: widget.otherAvatarUrl,
              displayName: widget.otherUsername,
              radius: 16,
            ),
            const SizedBox(width: 8),
            Text(
              widget.otherUsername,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, i) => _MessageBubble(
                message: messages[i],
                isOwn: messages[i].senderId == currentUserId,
                primaryColor: primary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !isSending,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle:
                            const TextStyle(color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: (_hasText && !isSending) ? _send : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (_hasText && !isSending)
                            ? primary
                            : const Color(0xFFD1D5DB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.primaryColor,
  });

  final MessageModel message;
  final bool isOwn;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            ProfileAvatar(
              avatarUrl: message.senderAvatarUrl,
              displayName: message.senderUsername ?? '?',
              radius: 12,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: isOwn ? primaryColor : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isOwn ? 18 : 4),
                  bottomRight: Radius.circular(isOwn ? 4 : 18),
                ),
              ),
              child: message.sharedPostId != null
                  ? _SharedPostPreview(message: message, isOwn: isOwn)
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(
                        message.body ?? '',
                        style: TextStyle(
                          color: isOwn ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
          ),
          if (isOwn) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SharedPostPreview extends StatelessWidget {
  const _SharedPostPreview({required this.message, required this.isOwn});

  final MessageModel message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isOwn ? 18 : 4),
        bottomRight: Radius.circular(isOwn ? 4 : 18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.sharedPostImageUrl != null)
            CachedNetworkImage(
              imageUrl: message.sharedPostImageUrl!,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  const ColoredBox(color: Color(0xFFE5E7EB)),
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: Color(0xFFE5E7EB)),
            ),
          if (message.sharedPostCaption != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                message.sharedPostCaption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isOwn ? Colors.white : Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
