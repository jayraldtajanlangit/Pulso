import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/story_providers.dart';
import '../screens/story_creation_screen.dart';
import '../screens/story_viewer_screen.dart';
import '../story/story_model.dart';
import 'profile_avatar.dart';

class StoriesRow extends ConsumerStatefulWidget {
  const StoriesRow({super.key});

  @override
  ConsumerState<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends ConsumerState<StoriesRow> {
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;
    final followingIds =
        ref.read(followControllerProvider).followingByCurrentUser.toList();
    await ref.read(storyControllerProvider.notifier).loadActiveStories(
          followingIds: followingIds,
          currentUserId: userId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.session?.userId));
    final storiesByUser =
        ref.watch(storyControllerProvider.select((s) => s.storiesByUser));

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _OwnStoryTile(
            currentUserId: currentUserId,
            hasActiveStory: storiesByUser.containsKey(currentUserId),
            stories: storiesByUser[currentUserId] ?? [],
          ),
          ...storiesByUser.entries
              .where((e) => e.key != currentUserId)
              .map((e) => _UserStoryTile(userId: e.key, stories: e.value)),
        ],
      ),
    );
  }
}

class _OwnStoryTile extends StatelessWidget {
  const _OwnStoryTile({
    required this.currentUserId,
    required this.hasActiveStory,
    required this.stories,
  });

  final String? currentUserId;
  final bool hasActiveStory;
  final List<StoryModel> stories;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (stories.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryViewerScreen(
                storiesByUser: {currentUserId!: stories},
                initialUserId: currentUserId!,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoryCreationScreen()),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasActiveStory
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFD1D5DB),
                      width: hasActiveStory ? 2 : 1.5,
                    ),
                  ),
                  child: const ClipOval(
                    child: Icon(Icons.add, color: Color(0xFF9CA3AF), size: 28),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Your story',
              style: TextStyle(fontSize: 11, color: Color(0xFF374151)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserStoryTile extends StatelessWidget {
  const _UserStoryTile({required this.userId, required this.stories});

  final String userId;
  final List<StoryModel> stories;

  @override
  Widget build(BuildContext context) {
    final allSeen = stories.every((s) => s.viewedByCurrentUser);
    final label = stories.first.authorUsername ?? 'user';
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
            storiesByUser: {userId: stories},
            initialUserId: userId,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: allSeen
                    ? null
                    : LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: allSeen ? const Color(0xFFD1D5DB) : null,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(2),
                child: ProfileAvatar(
                  avatarUrl: stories.first.authorAvatarUrl,
                  displayName: label,
                  radius: 25,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: allSeen
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
