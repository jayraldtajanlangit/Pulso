import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/comment_providers.dart';
import 'profile_avatar.dart';

/// Sticky bottom comment input bar that submits via [CommentController].
class CommentInput extends ConsumerStatefulWidget {
  const CommentInput({
    super.key,
    required this.postId,
    this.currentUserAvatarUrl,
    this.currentUserDisplayName,
    this.hintText = 'Add a comment...',
  });

  final String postId;
  final String? currentUserAvatarUrl;
  final String? currentUserDisplayName;
  final String hintText;

  @override
  ConsumerState<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<CommentInput> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    _controller.clear();
    setState(() => _hasText = false);

    await ref.read(commentControllerProvider.notifier).addComment(
      postId: widget.postId,
      userId: session.userId,
      body: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isSubmitting = ref.watch(
      commentControllerProvider
          .select((s) => s.threadFor(widget.postId).isSubmitting),
    );
    final error = ref.watch(
      commentControllerProvider
          .select((s) => s.threadFor(widget.postId).errorMessage),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProfileAvatar(
                  avatarUrl: widget.currentUserAvatarUrl,
                  displayName: widget.currentUserDisplayName,
                  radius: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: Key('comment_input_${widget.postId}'),
                    controller: _controller,
                    enabled: !isSubmitting,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
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
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed:
                      (_hasText && !isSubmitting) ? _submit : null,
                  child: Text(
                    'Post',
                    style: TextStyle(
                      color: (_hasText && !isSubmitting)
                          ? primary
                          : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
