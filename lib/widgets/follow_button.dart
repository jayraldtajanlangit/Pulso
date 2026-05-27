import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';

/// Toggleable Follow/Following button.
///
/// Hides itself when the [targetUserId] is the current user (you can't follow
/// yourself). Parent screens should call
/// `FollowController.loadFollowState(...)` and `loadStats(...)` for accurate
/// initial state.
class FollowButton extends ConsumerWidget {
  const FollowButton({
    super.key,
    required this.targetUserId,
    this.compact = false,
  });

  final String targetUserId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final currentUserId = session?.userId;

    if (currentUserId == null || currentUserId == targetUserId) {
      return const SizedBox.shrink();
    }

    final isFollowing = ref.watch(
      followControllerProvider.select((s) => s.isFollowing(targetUserId)),
    );
    final isPending = ref.watch(
      followControllerProvider.select((s) => s.isPending(targetUserId)),
    );

    final theme = Theme.of(context);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 10);

    final label = isFollowing ? 'Following' : 'Follow';

    void onTap() {
      if (isPending) return;
      ref.read(followControllerProvider.notifier).toggleFollow(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      );
    }

    if (isFollowing) {
      return OutlinedButton(
        key: Key('follow_button_$targetUserId'),
        onPressed: isPending ? null : onTap,
        style: OutlinedButton.styleFrom(
          padding: padding,
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(label),
      );
    }

    return FilledButton(
      key: Key('follow_button_$targetUserId'),
      onPressed: isPending ? null : onTap,
      style: FilledButton.styleFrom(
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label),
    );
  }
}
