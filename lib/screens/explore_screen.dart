import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_model.dart';
import '../providers/post_providers.dart';
import 'post_detail_screen.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postControllerProvider);

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
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
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
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.posts.isEmpty
                    ? const _EmptyExplore()
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: state.posts.length,
                        itemBuilder: (context, i) {
                          final post = state.posts[i];
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
              placeholder: (_, __) =>
                  Container(color: const Color(0xFFE5E7EB)),
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFFE5E7EB)),
            )
          else
            Container(
              color: const Color(0xFFE5E7EB),
              child: const Icon(Icons.article_outlined, color: Color(0xFF9CA3AF)),
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
