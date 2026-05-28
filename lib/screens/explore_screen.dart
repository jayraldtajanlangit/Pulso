import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_model.dart';
import '../providers/post_providers.dart';
import '../providers/profile_providers.dart';
import '../profile/profile_model.dart';
import '../widgets/profile_avatar.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<ProfileModel> _profileResults = [];
  bool _isSearchingProfiles = false;
  int _profileSearchSerial = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(postControllerProvider).posts.isEmpty) {
        ref.read(postControllerProvider.notifier).loadFeed();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() => _query = query.toLowerCase());
    _searchProfiles(query);
  }

  Future<void> _searchProfiles(String query) async {
    final serial = ++_profileSearchSerial;
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _profileResults = [];
        _isSearchingProfiles = false;
      });
      return;
    }

    setState(() => _isSearchingProfiles = true);

    try {
      final results = await ref
          .read(profileRepositoryProvider)
          .searchProfiles(trimmed);
      if (!mounted || serial != _profileSearchSerial) return;
      setState(() {
        _profileResults = results;
        _isSearchingProfiles = false;
      });
    } catch (_) {
      if (!mounted || serial != _profileSearchSerial) return;
      setState(() {
        _profileResults = [];
        _isSearchingProfiles = false;
      });
    }
  }

  List<PostModel> _filterPosts(List<PostModel> posts) {
    if (_query.isEmpty) return posts;
    return posts.where((post) {
      return post.caption.toLowerCase().contains(_query) ||
          (post.authorUsername ?? '').toLowerCase().contains(_query) ||
          (post.authorDisplayName ?? '').toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postControllerProvider);
    final posts = _filterPosts(state.posts);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Explore',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username or caption...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_query.isNotEmpty &&
              (_isSearchingProfiles || _profileResults.isNotEmpty))
            _ProfileResultsSection(
              profiles: _profileResults,
              isLoading: _isSearchingProfiles,
              onProfileTap: (profile) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: profile.id),
                ),
              ),
            ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                ? const _EmptyExplore()
                : GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                    itemCount: posts.length,
                    itemBuilder: (context, i) {
                      final post = posts[i];
                      return _GridItem(
                        post: post,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: post),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileResultsSection extends StatelessWidget {
  const _ProfileResultsSection({
    required this.profiles,
    required this.isLoading,
    required this.onProfileTap,
  });

  final List<ProfileModel> profiles;
  final bool isLoading;
  final ValueChanged<ProfileModel> onProfileTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading && profiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    final height = math.min(220.0, profiles.length * 64.0);

    return Container(
      height: height,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: profiles.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
        itemBuilder: (context, i) {
          final profile = profiles[i];
          final title = profile.username ?? profile.displayName ?? 'User';
          final subtitle = profile.displayName;
          return ListTile(
            leading: ProfileAvatar(
              avatarUrl: profile.avatarUrl,
              displayName: title,
              radius: 20,
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: subtitle == null || subtitle == title
                ? null
                : Text(subtitle),
            onTap: () => onProfileTap(profile),
          );
        },
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({required this.post, required this.onTap});

  final PostModel post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (post.imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: post.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFFE5E7EB)),
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFFE5E7EB)),
            )
          else
            Container(
              color: const Color(0xFFE5E7EB),
              child: const Icon(
                Icons.article_outlined,
                color: Color(0xFF9CA3AF),
              ),
            ),
          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyExplore extends StatelessWidget {
  const _EmptyExplore();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Color(0xFFD1D5DB)),
          SizedBox(height: 16),
          Text(
            'Nothing to explore yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Color(0xFF374151),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Posts from the community will appear here.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
