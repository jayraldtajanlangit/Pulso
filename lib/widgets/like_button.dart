import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/like_providers.dart';

/// Heart-icon toggle button that reads/writes via [LikeController].
///
/// The parent screen is responsible for calling
/// `LikeController.loadForPosts(...)` and `subscribe(...)` so this widget can
/// stay dumb.
class LikeButton extends ConsumerWidget {
  const LikeButton({
    super.key,
    required this.postId,
    this.postOwnerId,
    this.iconSize = 24,
    this.likedColor,
    this.unlikedColor,
    this.onTapDisabledMessage,
  });

  final String postId;
  final String? postOwnerId;
  final double iconSize;

  /// Defaults to the app's primary color when liked.
  final Color? likedColor;
  final Color? unlikedColor;

  /// Optional snackbar message shown when the user isn't signed in.
  final String? onTapDisabledMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final status = ref.watch(
      likeControllerProvider.select((s) => s.statusFor(postId)),
    );

    final color = status.isLiked
        ? (likedColor ?? Theme.of(context).colorScheme.primary)
        : (unlikedColor ?? Theme.of(context).iconTheme.color);

    return IconButton(
      key: Key('like_button_$postId'),
      iconSize: iconSize,
      color: color,
      icon: Icon(status.isLiked ? Icons.favorite : Icons.favorite_border),
      onPressed: () {
        if (session == null) {
          final message = onTapDisabledMessage;
          if (message != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
          return;
        }
        ref.read(likeControllerProvider.notifier).toggle(
          postId: postId,
          currentUserId: session.userId,
          postOwnerId: postOwnerId,
        );
      },
    );
  }
}

/// Compact like-count text that reads from [LikeController].
class LikeCountText extends ConsumerWidget {
  const LikeCountText({super.key, required this.postId, this.style});

  final String postId;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      likeControllerProvider.select((s) => s.statusFor(postId).count),
    );
    return Text('$count', style: style);
  }
}
