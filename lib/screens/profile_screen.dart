import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_model.dart';
import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/post_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/follow_button.dart';
import '../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';
import 'post_detail_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    this.isOwnProfile = false,
  });

  final String userId;
  final bool isOwnProfile;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref
          .read(profileControllerProvider.notifier)
          .loadProfile(widget.userId);
      ref.read(postControllerProvider.notifier).loadPosts(widget.userId);
      ref.read(followControllerProvider.notifier).loadStats(widget.userId);

      // Only load follow-state when looking at someone else's profile.
      final currentUserId =
          ref.read(authControllerProvider).session?.userId;
      if (currentUserId != null && currentUserId != widget.userId) {
        ref.read(followControllerProvider.notifier).loadFollowState(
          currentUserId: currentUserId,
          targetUserId: widget.userId,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final postState = ref.watch(postControllerProvider);
    final stats = ref.watch(
      followControllerProvider.select((s) => s.statsFor(widget.userId)),
    );
    final profile = profileState.profile;

    final displayName = profile?.displayName ??
        profile?.username ??
        ref.read(authControllerProvider).session?.email ??
        'Profile';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          if (widget.isOwnProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
        ],
      ),
      body: profileState.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Profile header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + stats
                      Row(
                        children: [
                          ProfileAvatar(
                            avatarUrl: profile?.avatarUrl,
                            displayName: displayName,
                            radius: 44,
                            backgroundColor: const Color(0xFFE0E7FF),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatColumn(
                                  count: postState.posts.length,
                                  label: 'Posts',
                                ),
                                _StatColumn(
                                  count: stats.followers,
                                  label: 'Followers',
                                ),
                                _StatColumn(
                                  count: stats.following,
                                  label: 'Following',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Display name
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      // Bio
                      if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.bio!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Edit Profile / Follow button
                      if (widget.isOwnProfile)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.settings, size: 16),
                            label: const Text('Edit Profile'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditProfileScreen(userId: widget.userId),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FollowButton(targetUserId: widget.userId),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.black,
                  indicatorWeight: 1.5,
                  dividerColor: const Color(0xFFE5E7EB),
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on, size: 22)),
                    Tab(icon: Icon(Icons.bookmark_border, size: 22)),
                  ],
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      postState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : postState.posts.isEmpty
                              ? const _EmptyPosts()
                              : _PostsGrid(
                                  posts: postState.posts,
                                  onPostTap: (post) => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PostDetailScreen(post: post),
                                    ),
                                  ),
                                ),
                      const Center(
                        child: Text(
                          'No saved posts',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      ],
    );
  }
}

class _PostsGrid extends StatelessWidget {
  const _PostsGrid({required this.posts, required this.onPostTap});

  final List<PostModel> posts;
  final void Function(PostModel) onPostTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        return GestureDetector(
          onTap: () => onPostTap(post),
          child: post.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: const Color(0xFFE5E7EB)),
                  errorWidget: (_, _, _) =>
                      Container(color: const Color(0xFFE5E7EB)),
                )
              : Container(
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(
                    Icons.article_outlined,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
        );
      },
    );
  }
}

class _EmptyPosts extends StatelessWidget {
  const _EmptyPosts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No posts yet',
        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
      ),
    );
  }
}
