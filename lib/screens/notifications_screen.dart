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
      _loadAndMarkRead();
    });
  }

  Future<void> _loadAndMarkRead() async {
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;
    final controller = ref.read(notificationControllerProvider.notifier);
    await controller.load(userId);
    await controller.markAllRead(userId);
  }

  Future<void> _refresh() async {
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;
    await ref.read(notificationControllerProvider.notifier).load(userId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);

    // Group notifications into "Today", "This week", "Earlier".
    final groups = _groupByTime(state.notifications);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: false,
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
              ? _EmptyState(onRefresh: _refresh)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: _flattenedLength(groups),
                    itemBuilder: (context, i) {
                      final item = _itemAt(groups, i);
                      if (item is String) {
                        return _SectionHeader(label: item);
                      }
                      return _NotificationRow(
                        notification: item as NotificationModel,
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: const [
          SizedBox(height: 120),
          Icon(
            Icons.favorite_border,
            size: 56,
            color: Color(0xFFD1D5DB),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Activity On Your Posts',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 6),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "When someone likes, comments, or follows you, you'll see it here.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// Returns a map of section-label → notifications, preserving order.
Map<String, List<NotificationModel>> _groupByTime(
  List<NotificationModel> items,
) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfWeek = startOfToday.subtract(const Duration(days: 7));

  final today = <NotificationModel>[];
  final thisWeek = <NotificationModel>[];
  final earlier = <NotificationModel>[];

  for (final n in items) {
    if (n.createdAt.isAfter(startOfToday)) {
      today.add(n);
    } else if (n.createdAt.isAfter(startOfWeek)) {
      thisWeek.add(n);
    } else {
      earlier.add(n);
    }
  }

  final out = <String, List<NotificationModel>>{};
  if (today.isNotEmpty) out['Today'] = today;
  if (thisWeek.isNotEmpty) out['This week'] = thisWeek;
  if (earlier.isNotEmpty) out['Earlier'] = earlier;
  return out;
}

int _flattenedLength(Map<String, List<NotificationModel>> groups) {
  var n = 0;
  for (final list in groups.values) {
    n += 1 + list.length;
  }
  return n;
}

/// Returns a `String` header at index, or a `NotificationModel` row.
Object _itemAt(Map<String, List<NotificationModel>> groups, int index) {
  var cursor = 0;
  for (final entry in groups.entries) {
    if (index == cursor) return entry.key;
    cursor++;
    final size = entry.value.length;
    if (index < cursor + size) {
      return entry.value[index - cursor];
    }
    cursor += size;
  }
  throw StateError('Index $index out of bounds');
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final NotificationModel notification;

  ({IconData icon, Color color}) get _typeStyle {
    switch (notification.type) {
      case 'like':
        return (icon: Icons.favorite, color: const Color(0xFF3B82F6));
      case 'comment':
        return (icon: Icons.chat_bubble, color: const Color(0xFF60A5FA));
      case 'follow':
        return (icon: Icons.person_add_alt_1, color: const Color(0xFF8B5CF6));
      case 'story_like':
        return (icon: Icons.favorite, color: const Color(0xFFEC4899));
      default:
        return (icon: Icons.notifications, color: Colors.grey);
    }
  }

  String get _actionText {
    switch (notification.type) {
      case 'like':
        return 'liked your post';
      case 'comment':
        return 'commented on your post';
      case 'follow':
        return 'started following you';
      case 'story_like':
        return 'reacted to your story';
      default:
        return 'interacted with you';
    }
  }

  String _relativeTime() {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnread = !notification.read;
    final style = _typeStyle;

    return Material(
      color: isUnread
          ? const Color(0xFFEFF6FF)
          : Colors.white,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              _AvatarWithTypeIcon(
                avatarUrl: notification.actorAvatarUrl,
                displayName: notification.actorUsername ?? '?',
                typeIcon: style.icon,
                typeColor: style.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          height: 1.35,
                        ),
                        children: [
                          TextSpan(
                            text: notification.actorUsername ?? 'Someone',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: ' $_actionText'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relativeTime(),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (notification.type == 'follow')
                _FollowBackButton(actorId: notification.actorId)
              else if (notification.thumbnailImageUrl != null)
                _PostThumbnail(imageUrl: notification.thumbnailImageUrl!),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarWithTypeIcon extends StatelessWidget {
  const _AvatarWithTypeIcon({
    required this.avatarUrl,
    required this.displayName,
    required this.typeIcon,
    required this.typeColor,
  });

  final String? avatarUrl;
  final String displayName;
  final IconData typeIcon;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ProfileAvatar(
            avatarUrl: avatarUrl,
            displayName: displayName,
            radius: 22,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  typeIcon,
                  color: Colors.white,
                  size: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowBackButton extends ConsumerWidget {
  const _FollowBackButton({required this.actorId});

  final String actorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(
      authControllerProvider.select((s) => s.session?.userId),
    );
    if (currentUserId == null || currentUserId == actorId) {
      return const SizedBox.shrink();
    }

    final isFollowing = ref.watch(
      followControllerProvider.select((s) => s.isFollowing(actorId)),
    );

    return GestureDetector(
      onTap: () {
        ref
            .read(followControllerProvider.notifier)
            .toggleFollow(currentUserId: currentUserId, targetUserId: actorId);
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
        errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFFE5E7EB)),
      ),
    );
  }
}
