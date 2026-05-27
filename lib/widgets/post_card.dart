import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_model.dart';
import '../providers/comment_providers.dart';
import 'like_button.dart';
import 'profile_avatar.dart';

/// Feed-style card for a single post.
///
/// Like and comment counts are read live from their controllers when the
/// parent has populated them (see `LikeController.loadForPosts` and
/// `CommentController.loadCountsForPosts`).
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onComment,
    this.onAvatarTap,
    this.onUsernameTap,
    this.onBookmark,
    this.isBookmarked = false,
  });

  final PostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onComment;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onUsernameTap;
  final VoidCallback? onBookmark;
  final bool isBookmarked;

  String get _displayUsername {
    final username = post.authorUsername;
    if (username != null && username.isNotEmpty) return username;
    final display = post.authorDisplayName;
    if (display != null && display.isNotEmpty) return display;
    return post.userId.substring(0, post.userId.length.clamp(0, 8));
  }

  String get _formattedDate {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${months[post.createdAt.month - 1]} ${post.createdAt.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveCommentCount = ref.watch(
      commentControllerProvider.select((s) => s.counts[post.id]),
    );
    final commentCount = liveCommentCount ?? post.commentCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: ProfileAvatar(
                  avatarUrl: post.authorAvatarUrl,
                  displayName: _displayUsername,
                  radius: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onUsernameTap,
                  child: Text(
                    _displayUsername,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const Icon(Icons.more_horiz, size: 20),
            ],
          ),
        ),
        // Image
        if (post.imageUrl.isNotEmpty)
          GestureDetector(
            onTap: onTap,
            child: CachedNetworkImage(
              imageUrl: post.imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                height: 300,
                color: const Color(0xFFE5E7EB),
              ),
              errorWidget: (_, _, _) => Container(
                height: 300,
                color: const Color(0xFFE5E7EB),
                child: const Icon(
                  Icons.broken_image,
                  color: Color(0xFF9CA3AF),
                  size: 48,
                ),
              ),
            ),
          ),
        // Actions row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              LikeButton(postId: post.id),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: onComment,
              ),
              IconButton(
                icon: const Icon(Icons.send_outlined),
                onPressed: () {},
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                onPressed: onBookmark,
              ),
            ],
          ),
        ),
        // Counts
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              LikeCountText(
                postId: post.id,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.favorite, size: 13, color: Colors.black87),
              const SizedBox(width: 12),
              Text(
                '$commentCount',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chat_bubble_outline,
                size: 13,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        // Caption
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 13),
                children: [
                  TextSpan(
                    text: '$_displayUsername ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),
        // Date
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            _formattedDate,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
