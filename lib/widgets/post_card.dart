import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../post/post_model.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.username,
    this.avatarUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onBookmark,
  });

  final PostModel post;
  final String? username;
  final String? avatarUrl;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onBookmark;

  String get _displayUsername =>
      username ?? post.userId.substring(0, post.userId.length.clamp(0, 8));

  String get _formattedDate {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${months[post.createdAt.month - 1]} ${post.createdAt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _AvatarWidget(avatarUrl: avatarUrl, username: _displayUsername),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _displayUsername,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.more_horiz, size: 20),
            ],
          ),
        ),
        // Image
        if (post.imageUrl != null)
          GestureDetector(
            onDoubleTap: onLike,
            onTap: onTap,
            child: CachedNetworkImage(
              imageUrl: post.imageUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 300,
                color: const Color(0xFFE5E7EB),
              ),
              errorWidget: (_, __, ___) => Container(
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
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : null,
                ),
                onPressed: onLike,
              ),
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
        // Like count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '$likeCount',
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
              const Icon(Icons.chat_bubble_outline, size: 13, color: Colors.black87),
            ],
          ),
        ),
        // Caption
        if (post.content.isNotEmpty)
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
                  TextSpan(text: post.content),
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

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.avatarUrl, required this.username});

  final String? avatarUrl;
  final String username;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundImage:
          avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
      backgroundColor: const Color(0xFFE5E7EB),
      child: avatarUrl == null
          ? Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            )
          : null,
    );
  }
}
