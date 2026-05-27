import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/profile_providers.dart';
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
      height: 104,
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

class _OwnStoryTile extends ConsumerWidget {
  const _OwnStoryTile({
    required this.currentUserId,
    required this.hasActiveStory,
    required this.stories,
  });

  final String? currentUserId;
  final bool hasActiveStory;
  final List<StoryModel> stories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl =
        ref.watch(profileControllerProvider.select((s) => s.profile?.avatarUrl));
    final username =
        ref.watch(profileControllerProvider.select((s) => s.profile?.username));
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                children: [
                  // Avatar with ring — tap to view own story
                  GestureDetector(
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
                          MaterialPageRoute(
                              builder: (_) => const StoryCreationScreen()),
                        );
                      }
                    },
                    child: Container(
                      width: 66,
                      height: 66,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasActiveStory
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFF58529),
                                  Color(0xFFDD2A7B),
                                  Color(0xFF8134AF),
                                  Color(0xFF515BD4),
                                ],
                                begin: Alignment.bottomLeft,
                                end: Alignment.topRight,
                              )
                            : null,
                        color: hasActiveStory ? null : const Color(0xFFD1D5DB),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: ProfileAvatar(
                          avatarUrl: avatarUrl,
                          displayName: username ?? 'You',
                          radius: 27,
                        ),
                      ),
                    ),
                  ),
                  // + badge — always tappable to create a new story
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StoryCreationScreen()),
                      ),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your story',
              style: TextStyle(fontSize: 11, color: Color(0xFF374151)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
        child: SizedBox(
          width: 66,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: allSeen
                      ? null
                      : const LinearGradient(
                          colors: [
                            Color(0xFFF58529),
                            Color(0xFFDD2A7B),
                            Color(0xFF8134AF),
                            Color(0xFF515BD4),
                          ],
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
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
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
