import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_model.dart';
import '../providers/auth_providers.dart';
import '../providers/like_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/comment_input.dart';
import '../widgets/comment_list.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final PostModel post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authControllerProvider).session?.userId;
      if (userId == null) return;
      ref
          .read(likeControllerProvider.notifier)
          .subscribe(currentUserId: userId);
      ref.read(likeControllerProvider.notifier).loadForPost(
        postId: widget.post.id,
        currentUserId: userId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile =
        ref.watch(profileControllerProvider.select((s) => s.profile));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(),
        title: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PostCard(
                    post: widget.post,
                    onDeleted: () => Navigator.of(context).pop(),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  CommentList(
                    postId: widget.post.id,
                    postOwnerId: widget.post.userId,
                  ),
                ],
              ),
            ),
          ),
          CommentInput(
            postId: widget.post.id,
            postOwnerId: widget.post.userId,
            currentUserAvatarUrl: currentProfile?.avatarUrl,
            currentUserDisplayName:
                currentProfile?.displayName ?? currentProfile?.username,
          ),
        ],
      ),
    );
  }
}
