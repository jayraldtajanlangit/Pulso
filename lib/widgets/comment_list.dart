import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../comment/comment_model.dart';
import '../providers/auth_providers.dart';
import '../providers/comment_providers.dart';
import 'profile_avatar.dart';

/// Renders the comment thread for a post, Instagram-style:
/// - Each comment has a like heart with a count
/// - "Reply" action below each comment that sets the input's reply target
/// - "View N replies" expands a nested list under the parent comment
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
      final userId = ref.read(authControllerProvider).session?.userId;
      final notifier = ref.read(commentControllerProvider.notifier);
      notifier.setCurrentUser(userId);
      notifier.loadComments(widget.postId);
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
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final comment = thread.comments[i];
        final replies = thread.repliesByParent[comment.id];
        final canDelete = currentUserId != null &&
            (comment.userId == currentUserId ||
                widget.postOwnerId == currentUserId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentTile(
              comment: comment,
              postId: widget.postId,
              canDelete: canDelete,
              onDelete: () => ref
                  .read(commentControllerProvider.notifier)
                  .deleteComment(
                    postId: widget.postId,
                    commentId: comment.id,
                  ),
            ),
            if (comment.replyCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(42, 6, 0, 0),
                child: _ToggleRepliesButton(
                  postId: widget.postId,
                  parentCommentId: comment.id,
                  replyCount: comment.replyCount,
                  isExpanded: replies != null,
                ),
              ),
            if (replies != null && replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(42, 8, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final reply in replies) ...[
                      _CommentTile(
                        comment: reply,
                        postId: widget.postId,
                        canDelete: currentUserId != null &&
                            (reply.userId == currentUserId ||
                                widget.postOwnerId == currentUserId),
                        onDelete: () => ref
                            .read(commentControllerProvider.notifier)
                            .deleteComment(
                              postId: widget.postId,
                              commentId: reply.id,
                            ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ToggleRepliesButton extends ConsumerWidget {
  const _ToggleRepliesButton({
    required this.postId,
    required this.parentCommentId,
    required this.replyCount,
    required this.isExpanded,
  });

  final String postId;
  final String parentCommentId;
  final int replyCount;
  final bool isExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(commentControllerProvider.notifier);
    return GestureDetector(
      onTap: () {
        if (isExpanded) {
          notifier.collapseReplies(
            postId: postId,
            parentCommentId: parentCommentId,
          );
        } else {
          notifier.loadReplies(
            postId: postId,
            parentCommentId: parentCommentId,
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 1,
              color: const Color(0xFFD1D5DB),
            ),
            const SizedBox(width: 10),
            Text(
              isExpanded
                  ? 'Hide replies'
                  : 'View ${replyCount == 1 ? "1 reply" : "$replyCount replies"}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.canDelete,
    required this.onDelete,
  });

  final CommentModel comment;
  final String postId;
  final bool canDelete;
  final VoidCallback onDelete;

  String get _displayName =>
      comment.authorUsername ??
      comment.authorDisplayName ??
      'user_${comment.userId.substring(0, comment.userId.length.clamp(0, 6))}';

  String get _relativeTime {
    final diff = DateTime.now().difference(comment.createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final currentUserId =
        ref.watch(authControllerProvider).session?.userId;

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
                        height: 1.35,
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
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _relativeTime,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                  ),
                  if (comment.likeCount > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${comment.likeCount} ${comment.likeCount == 1 ? "like" : "likes"}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      // Set reply target: if this is itself a reply, attach
                      // to its parent so threads stay flat (Instagram-style).
                      final targetId =
                          comment.parentCommentId ?? comment.id;
                      ref
                          .read(replyTargetProvider(postId).notifier)
                          .set(
                            ReplyTarget(
                              commentId: targetId,
                              username: _displayName,
                            ),
                          );
                    },
                    child: const Text(
                      'Reply',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (canDelete) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Heart toggle on the right
        GestureDetector(
          onTap: () {
            if (currentUserId == null) return;
            ref
                .read(commentControllerProvider.notifier)
                .toggleCommentLike(
                  postId: postId,
                  commentId: comment.id,
                  userId: currentUserId,
                );
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Icon(
              comment.isLikedByMe
                  ? Icons.favorite
                  : Icons.favorite_border,
              size: 16,
              color: comment.isLikedByMe ? primary : const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }
}
