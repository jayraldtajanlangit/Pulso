import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'inbox_screen.dart';
import 'explore_screen.dart';
import 'feed_screen.dart';
import 'post_creation_screen.dart';
import 'profile_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  // Post (index 2) is a modal — map nav index to stack index
  int get _stackIndex => _index > 2 ? _index - 1 : _index;

  void _onTap(int i, String userId) {
    if (i == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostCreationScreen(userId: userId),
        ),
      );
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final userId =
        ref.watch(authControllerProvider).session?.userId ?? '';

    return Scaffold(
      body: IndexedStack(
        index: _stackIndex,
        children: [
          const FeedScreen(),
          const ExploreScreen(),
          const InboxScreen(),
          ProfileScreen(userId: userId, isOwnProfile: true),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _index,
        onTap: (i) => _onTap(i, userId),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home, 'Feed'),
    _NavItem(Icons.local_fire_department_outlined, Icons.local_fire_department, 'Explore'),
    _NavItem(Icons.add_box_outlined, Icons.add_box, 'Post'),
    _NavItem(Icons.send_outlined, Icons.send, 'Messages'),
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
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? _items[i].activeIcon : _items[i].icon,
                        color: isActive ? primary : inactive,
                        size: 24,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive ? primary : inactive,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
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
