import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_model.dart';
import '../providers/auth_providers.dart';
import '../providers/comment_providers.dart';
import '../providers/like_providers.dart';
import '../providers/post_providers.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool _didInit = false;
  String? _lastHydratedFingerprint;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    if (_didInit) return;
    _didInit = true;
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;
    try {
      // Start realtime likes channel once.
      ref
          .read(likeControllerProvider.notifier)
          .subscribe(currentUserId: userId);
      await ref.read(postControllerProvider.notifier).loadFeed();
    } catch (_) {
      // Supabase not configured (e.g., during widget tests). Render anyway.
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(postControllerProvider.notifier).loadFeed();
    } catch (_) {
      // Ignore — refresh is best-effort.
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Trigger loadMore when within 400px of the bottom.
    if (position.pixels >= position.maxScrollExtent - 400) {
      try {
        ref.read(postControllerProvider.notifier).loadMoreFeed();
      } catch (_) {
        // Ignore — pagination is best-effort.
      }
    }
  }

  void _hydrateCounts(List<PostModel> posts, String userId) {
    if (posts.isEmpty) return;
    final fingerprint = posts.map((p) => p.id).join(',');
    if (fingerprint == _lastHydratedFingerprint) return;
    _lastHydratedFingerprint = fingerprint;

    try {
      final ids = posts.map((p) => p.id).toList();
      ref.read(likeControllerProvider.notifier).loadForPosts(
        postIds: ids,
        currentUserId: userId,
      );
      ref
          .read(commentControllerProvider.notifier)
          .loadCountsForPosts(ids);
    } catch (_) {
      // Supabase not configured. Skip hydration.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postControllerProvider);
    final userId = ref.watch(authControllerProvider).session?.userId;

    if (userId != null) {
      _hydrateCounts(state.posts, userId);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          'Pulso',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            const SliverToBoxAdapter(child: _StoriesRow()),
            const SliverToBoxAdapter(
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFFE5E7EB),
              ),
            ),
            if (state.isLoading && state.posts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.posts.isEmpty)
              const SliverFillRemaining(child: _EmptyFeed())
            else ...[
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final post = state.posts[i];
                    return Column(
                      children: [
                        PostCard(
                          post: post,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: post),
                            ),
                          ),
                          onComment: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: post),
                            ),
                          ),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: Color(0xFFE5E7EB),
                        ),
                      ],
                    );
                  },
                  childCount: state.posts.length,
                ),
              ),
              SliverToBoxAdapter(
                child: _FeedFooter(
                  isLoadingMore: state.isLoadingMore,
                  hasMore: state.hasMore,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: const [
          _StoryItem(label: 'Your story', isAddStory: true),
        ],
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  const _StoryItem({required this.label, this.isAddStory = false});

  final String label;
  final bool isAddStory;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
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
                    color: const Color(0xFFD1D5DB),
                    width: 1.5,
                  ),
                ),
                child: const ClipOval(
                  child: Icon(
                    Icons.add,
                    color: Color(0xFF9CA3AF),
                    size: 28,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.isLoadingMore, required this.hasMore});

  final bool isLoadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            "You're all caught up",
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ),
      );
    }
    return const SizedBox(height: 32);
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 64,
            color: Color(0xFFD1D5DB),
          ),
          SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Color(0xFF374151),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first post or pull down to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
