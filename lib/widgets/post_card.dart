import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_model.dart';
import '../providers/auth_providers.dart';
import '../providers/comment_providers.dart';
import '../providers/like_providers.dart';
import '../providers/post_providers.dart';
import 'like_button.dart';
import 'profile_avatar.dart';

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
    this.onDeleted,
  });

  final PostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onComment;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onUsernameTap;
  final VoidCallback? onBookmark;
  final bool isBookmarked;
  final VoidCallback? onDeleted;

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

  Future<void> _showEditSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: post.caption);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Edit Caption',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Write a caption...',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref.read(postControllerProvider.notifier).editPost(
                      post.id,
                      caption: controller.text,
                    );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('This post will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(postControllerProvider.notifier).deletePost(post.id);
      onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.session?.userId));
    final isOwner = currentUserId == post.userId;

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
              if (isOwner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (value) {
                    if (value == 'edit') _showEditSheet(context, ref);
                    if (value == 'delete') _confirmDelete(context, ref);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit caption'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                )
              else
                const Icon(Icons.more_horiz, size: 20),
            ],
          ),
        ),
        // Image carousel with double-tap to like
        if (post.imageUrls.isNotEmpty)
          _DoubleTapLikeWrapper(
            postId: post.id,
            onTap: onTap,
            child: _ImageCarousel(images: post.imageUrls),
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
              _BookmarkButton(initialValue: isBookmarked, onToggle: onBookmark),
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
        // Caption — live from controller so edits reflect immediately
        _CaptionText(
          postId: post.id,
          fallback: post.caption,
          username: _displayUsername,
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

// ─── Double-tap to like ───────────────────────────────────────────────────────

class _DoubleTapLikeWrapper extends ConsumerStatefulWidget {
  const _DoubleTapLikeWrapper({
    required this.postId,
    required this.child,
    this.onTap,
  });

  final String postId;
  final Widget child;
  final VoidCallback? onTap;

  @override
  ConsumerState<_DoubleTapLikeWrapper> createState() =>
      _DoubleTapLikeWrapperState();
}

class _DoubleTapLikeWrapperState extends ConsumerState<_DoubleTapLikeWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _heartVisible = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ctrl);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _heartVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;

    final isLiked =
        ref.read(likeControllerProvider).statusFor(widget.postId).isLiked;
    if (!isLiked) {
      ref.read(likeControllerProvider.notifier).toggle(
            postId: widget.postId,
            currentUserId: session.userId,
          );
    }

    setState(() => _heartVisible = true);
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _onDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_heartVisible)
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) => Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: child,
                ),
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 90,
                shadows: [Shadow(color: Colors.black38, blurRadius: 20)],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Live caption ─────────────────────────────────────────────────────────────

class _CaptionText extends ConsumerWidget {
  const _CaptionText({
    required this.postId,
    required this.fallback,
    required this.username,
  });

  final String postId;
  final String fallback;
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caption = ref.watch(
          postControllerProvider.select(
            (s) => s.posts
                .where((p) => p.id == postId)
                .map((p) => p.caption)
                .firstOrNull,
          ),
        ) ??
        fallback;

    if (caption.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 13),
          children: [
            TextSpan(
              text: '$username ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: caption),
          ],
        ),
      ),
    );
  }
}

// ─── Bookmark toggle ──────────────────────────────────────────────────────────

class _BookmarkButton extends StatefulWidget {
  const _BookmarkButton({required this.initialValue, this.onToggle});

  final bool initialValue;
  final VoidCallback? onToggle;

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  late bool _bookmarked;

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_border),
      onPressed: () {
        setState(() => _bookmarked = !_bookmarked);
        widget.onToggle?.call();
      },
    );
  }
}

// ─── Image carousel ───────────────────────────────────────────────────────────

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.images});

  final List<String> images;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _current = 0;
  late final PageController _pageController;

  // Aspect ratio is resolved once from the first image and fixed for the
  // entire carousel so the layout never shifts when swiping.
  late final Future<double> _ratioFuture = _resolveRatio(widget.images.first);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<double> _resolveRatio(String url) async {
    final completer = Completer<double>();
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final ratio = info.image.width / info.image.height;
        if (!completer.isCompleted) completer.complete(ratio);
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        if (!completer.isCompleted) completer.complete(1.0);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;

    return FutureBuilder<double>(
      future: _ratioFuture,
      initialData: 1.0,
      builder: (context, snapshot) {
        final ratio = snapshot.data ?? 1.0;

        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            AspectRatio(
              aspectRatio: ratio,
              child: PageView.builder(
                controller: _pageController,
                itemCount: count,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => CachedNetworkImage(
                  imageUrl: widget.images[i],
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const ColoredBox(color: Color(0xFFE5E7EB)),
                  errorWidget: (context, url, error) => const ColoredBox(
                    color: Color(0xFFE5E7EB),
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Color(0xFF9CA3AF),
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (count > 1) ...[
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_current + 1}/$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    math.min(count, 10),
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _current ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _current
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
