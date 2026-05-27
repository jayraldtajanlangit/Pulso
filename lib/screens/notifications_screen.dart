import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notification/notification_model.dart';
import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/notification_providers.dart';
import '../widgets/profile_avatar.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authControllerProvider).session?.userId;
      if (userId == null) return;
      ref.read(notificationControllerProvider.notifier).markAllRead(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
              ? const Center(
                  child: Text(
                    'No notifications yet',
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                )
              : ListView.builder(
                  itemCount: state.notifications.length,
                  itemBuilder: (context, i) =>
                      _NotificationRow(notification: state.notifications[i]),
                ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final NotificationModel notification;

  String get _actionText {
    switch (notification.type) {
      case 'like':
        return 'liked your post';
      case 'comment':
        return 'commented on your post';
      case 'follow':
        return 'started following you';
      case 'message':
        return 'sent you a message';
      default:
        return 'interacted with you';
    }
  }

  String _relativeTime() {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final isUnread = !notification.read;

    return Container(
      decoration: isUnread
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: primary, width: 3),
              ),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isUnread ? 13 : 16, 10, 12, 10),
        child: Row(
          children: [
            ProfileAvatar(
              avatarUrl: notification.actorAvatarUrl,
              displayName: notification.actorUsername ?? '?',
              radius: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 13),
                  children: [
                    TextSpan(
                      text: '${notification.actorUsername ?? 'Someone'} ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: _actionText),
                    TextSpan(
                      text: '  ${_relativeTime()}',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (notification.type == 'follow')
              _FollowBackButton(actorId: notification.actorId)
            else if (notification.postImageUrl != null)
              _PostThumbnail(imageUrl: notification.postImageUrl!),
          ],
        ),
      ),
    );
  }
}

class _FollowBackButton extends ConsumerWidget {
  const _FollowBackButton({required this.actorId});

  final String actorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.session?.userId));
    if (currentUserId == null || currentUserId == actorId) {
      return const SizedBox.shrink();
    }

    final isFollowing = ref.watch(
      followControllerProvider.select((s) => s.isFollowing(actorId)),
    );

    return GestureDetector(
      onTap: () {
        ref.read(followControllerProvider.notifier).toggleFollow(
          currentUserId: currentUserId,
          targetUserId: actorId,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.transparent
              : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
          border: isFollowing
              ? Border.all(color: const Color(0xFFD1D5DB))
              : null,
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: isFollowing ? Colors.black87 : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PostThumbnail extends StatelessWidget {
  const _PostThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(color: Color(0xFFE5E7EB)),
        errorWidget: (_, __, ___) =>
            const ColoredBox(color: Color(0xFFE5E7EB)),
      ),
    );
  }
}
