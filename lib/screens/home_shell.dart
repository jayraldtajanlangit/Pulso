import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/like_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/post_providers.dart';
import 'explore_screen.dart';
import 'feed_screen.dart';
import 'notifications_screen.dart';
import 'post_creation_screen.dart';
import 'profile_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // Tabs (indexes that map into the IndexedStack):
  //   0 — Feed
  //   1 — Explore
  //   4 — Profile
  // Modal-route items (don't change _index):
  //   2 — Post creation
  //   3 — Notifications (the bell)
  int _index = 0;

  /// IndexedStack only contains the three persistent screens (Feed, Explore,
  /// Profile). _index 0 → 0, 1 → 1, 4 → 2.
  int get _stackIndex {
    if (_index == 4) return 2;
    return _index; // 0 or 1
  }

  void _onTap(int i, String userId) {
    // Post (nav index 2) — push the creation screen as a modal.
    if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostCreationScreen(userId: userId),
        ),
      );
      return;
    }
    // Notifications (nav index 3) — push the notifications screen.
    if (i == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      return;
    }
    // Re-hydrate like counts when the user comes back to the Feed tab —
    // recovers from any realtime gaps without a full feed reload.
    if (i == 0 && userId.isNotEmpty) {
      ref
          .read(likeControllerProvider.notifier)
          .refreshAllKnownPosts(userId);
    }
    // Refresh own profile stats + post grid every time the profile tab is
    // opened. profilePostsProvider is a cached family provider — without
    // explicit invalidation, posts created in this session would only show
    // up after a full app restart.
    if (i == 4 && userId.isNotEmpty) {
      ref.read(followControllerProvider.notifier).loadStats(userId);
      ref.invalidate(profilePostsProvider(userId));
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final userId =
        ref.watch(authControllerProvider).session?.userId ?? '';

    final unreadNotifications = ref.watch(
      notificationControllerProvider.select((s) => s.unreadCount),
    );

    return Scaffold(
      body: IndexedStack(
        index: _stackIndex,
        children: [
          const FeedScreen(),
          const ExploreScreen(),
          ProfileScreen(userId: userId, isOwnProfile: true),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _index,
        unreadNotifications: unreadNotifications,
        onTap: (i) => _onTap(i, userId),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    this.unreadNotifications = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadNotifications;

  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home, 'Feed'),
    _NavItem(
      Icons.local_fire_department_outlined,
      Icons.local_fire_department,
      'Explore',
    ),
    _NavItem(Icons.add_box_outlined, Icons.add_box, 'Post'),
    _NavItem(Icons.notifications_none, Icons.notifications, 'Notifications'),
    _NavItem(Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const inactive = Color(0xFF9CA3AF);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final isActive = currentIndex == i;
              final showBadge = i == 3 && unreadNotifications > 0;
              final isPost = i == 2;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // The Post tab gets a circular outline so it stands
                          // out as the primary action — matches Instagram's
                          // visually distinct create button.
                          if (isPost)
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primary,
                                  width: 1.8,
                                ),
                              ),
                              child: Icon(
                                Icons.add,
                                color: primary,
                                size: 22,
                              ),
                            )
                          else
                            Icon(
                              isActive ? _items[i].activeIcon : _items[i].icon,
                              color: isActive ? primary : inactive,
                              size: 24,
                            ),
                          if (showBadge)
                            Positioned(
                              top: -4,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  unreadNotifications > 9
                                      ? '9+'
                                      : '$unreadNotifications',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          color: (isActive || isPost) ? primary : inactive,
                          fontWeight: (isActive || isPost)
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
