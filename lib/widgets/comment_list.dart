import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../comment/comment_model.dart';
import '../providers/auth_providers.dart';
import '../providers/comment_providers.dart';
import 'profile_avatar.dart';

/// Renders the comment thread for a post.
///
/// On mount, triggers `CommentController.loadComments(postId)` which also
/// starts the realtime subscription for the thread.
class CommentList extends ConsumerStatefulWidget {
  const CommentList({
    super.key,
    required this.postId,
    required this.postOwnerId,
    this.emptyStateMessage = 'No comments yet. Be the first!',
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.shrinkWrap = true,
    this.scrollPhysics,
  });

  final String postId;

  /// User id of the post owner — used to decide if a delete button should
  /// appear on a comment authored by someone else.
  final String postOwnerId;
  final String emptyStateMessage;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? scrollPhysics;

  @override
  ConsumerState<CommentList> createState() => _CommentListState();
}

class _CommentListState extends ConsumerState<CommentList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(commentControllerProvider.notifier)
          .loadComments(widget.postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(
      commentControllerProvider.select((s) => s.threadFor(widget.postId)),
    );
    final currentUserId =
        ref.watch(authControllerProvider).session?.userId;

    if (thread.isLoading && thread.comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (thread.comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Center(
          child: Text(
            widget.emptyStateMessage,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.scrollPhysics ??
          (widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null),
      padding: widget.padding,
      itemCount: thread.comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final comment = thread.comments[i];
        final canDelete = currentUserId != null &&
            (comment.userId == currentUserId ||
                widget.postOwnerId == currentUserId);
        return _CommentTile(
          comment: comment,
          canDelete: canDelete,
          onDelete: () => ref
              .read(commentControllerProvider.notifier)
              .deleteComment(postId: widget.postId, commentId: comment.id),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final CommentModel comment;
  final bool canDelete;
  final VoidCallback onDelete;

  String get _displayName =>
      comment.authorDisplayName ??
      comment.authorUsername ??
      comment.userId.substring(0, comment.userId.length.clamp(0, 8));

  String get _relativeTime {
    final diff = DateTime.now().difference(comment.createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileAvatar(
          avatarUrl: comment.authorAvatarUrl,
          displayName: _displayName,
          radius: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style.copyWith(
                        fontSize: 13,
                        color: Colors.black,
                      ),
                  children: [
                    TextSpan(
                      text: '$_displayName ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: comment.body),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _relativeTime,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
        ),
        if (canDelete)
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, color: Color(0xFF9CA3AF)),
            onPressed: onDelete,
          ),
      ],
    );
  }
}
