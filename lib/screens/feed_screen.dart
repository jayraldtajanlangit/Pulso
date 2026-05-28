import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_model.dart';
import '../providers/auth_providers.dart';
import '../providers/bookmark_providers.dart';
import '../providers/comment_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/like_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/post_providers.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_row.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  bool _didInit = false;
  String? _lastHydratedFingerprint;
  final _scrollController = ScrollController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isFollowingTab => _tabController.index == 1;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _lastHydratedFingerprint = null;
    _refresh();
  }

  Future<void> _initialLoad() async {
    if (_didInit) return;
    _didInit = true;
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;

    try {
      ref
          .read(likeControllerProvider.notifier)
          .subscribe(currentUserId: userId);
    } catch (_) {}

    // Keep feed-level comment counts in sync across clients, even when the
    // user hasn't opened a specific post's comment list.
    try {
      ref
          .read(commentControllerProvider.notifier)
          .ensureGlobalCountsSubscription();
    } catch (_) {}

    await Future.wait([
      ref.read(postControllerProvider.notifier).loadFeed(),
      ref.read(followControllerProvider.notifier).loadFollowingIds(userId),
    ]);

    try {
      ref.read(notificationControllerProvider.notifier).load(userId);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;
    try {
      if (_isFollowingTab) {
        final followingIds = ref
            .read(followControllerProvider)
            .followingByCurrentUser
            .toList();
        await ref
            .read(postControllerProvider.notifier)
            .loadFollowingFeed(followingIds: followingIds);
      } else {
        await ref.read(postControllerProvider.notifier).loadFeed();
      }
    } catch (_) {}
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final state = ref.read(postControllerProvider);
    if (state.isLoadingMore || !state.hasMore) return;
    final position = _scrollController.position;
    if (position.userScrollDirection != ScrollDirection.reverse) return;
    if (position.pixels >= position.maxScrollExtent - 400) {
      try {
        if (_isFollowingTab) {
          final followingIds = ref
              .read(followControllerProvider)
              .followingByCurrentUser
              .toList();
          ref
              .read(postControllerProvider.notifier)
              .loadMoreFollowingFeed(followingIds: followingIds);
        } else {
          ref.read(postControllerProvider.notifier).loadMoreFeed();
        }
      } catch (_) {}
    }
  }

  void _hydrateCounts(List<PostModel> posts, String userId) {
    if (posts.isEmpty) return;
    final fingerprint = posts.map((p) => p.id).join(',');
    if (fingerprint == _lastHydratedFingerprint) return;
    _lastHydratedFingerprint = fingerprint;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final ids = posts.map((p) => p.id).toList();
        ref
            .read(likeControllerProvider.notifier)
            .loadForPosts(postIds: ids, currentUserId: userId);
        ref
            .read(bookmarkControllerProvider.notifier)
            .loadForPosts(postIds: ids, userId: userId);
        ref.read(commentControllerProvider.notifier).loadCountsForPosts(ids);
      } catch (_) {
        // Supabase not configured. Skip hydration.
      }
    });
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
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: const Color(0xFF9CA3AF),
          tabs: const [
            Tab(text: 'For You'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: StoriesRow()),
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
            else if (state.errorMessage != null && state.posts.isEmpty)
              SliverFillRemaining(
                child: _FeedError(
                  message: state.errorMessage!,
                  onRetry: _refresh,
                ),
              )
            else if (state.posts.isEmpty)
              SliverFillRemaining(
                child: _isFollowingTab
                    ? const _EmptyFollowingFeed()
                    : const _EmptyFeed(),
              )
            else ...[
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final post = state.posts[i];
                  final isBookmarked = userId == null
                      ? false
                      : ref.watch(
                          bookmarkControllerProvider.select(
                            (s) => s.isBookmarked(post.id),
                          ),
                        );
                  return Column(
                    children: [
                      PostCard(
                        post: post,
                        isBookmarked: isBookmarked,
                        onBookmark: userId == null
                            ? null
                            : () => ref
                                  .read(bookmarkControllerProvider.notifier)
                                  .toggle(postId: post.id, userId: userId),
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
                        onAvatarTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: post.userId),
                          ),
                        ),
                        onUsernameTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: post.userId),
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
                }, childCount: state.posts.length),
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

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text(
              "Couldn't load the feed",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
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
          Icon(Icons.photo_camera_outlined, size: 64, color: Color(0xFFD1D5DB)),
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

class _EmptyFollowingFeed extends StatelessWidget {
  const _EmptyFollowingFeed();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Color(0xFFD1D5DB)),
          SizedBox(height: 16),
          Text(
            'No posts from people you follow',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Color(0xFF374151),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Follow people to see their posts here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
