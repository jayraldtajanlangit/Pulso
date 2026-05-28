import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../comment/comment_controller.dart';
import '../comment/comment_repository.dart';
import 'supabase_providers.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseCommentRepository(client);
});

final commentControllerProvider =
    NotifierProvider<CommentController, CommentState>(CommentController.new);

/// Tracks which comment the user is currently replying to per post.
/// Value = (commentId, username) of the parent comment, or null if writing
/// a top-level comment.
class ReplyTarget {
  const ReplyTarget({required this.commentId, required this.username});
  final String commentId;
  final String username;
}

class ReplyTargetController extends Notifier<ReplyTarget?> {
  ReplyTargetController(this.postId);

  final String postId;

  @override
  ReplyTarget? build() => null;

  void set(ReplyTarget? target) => state = target;
  void clear() => state = null;
}

final replyTargetProvider =
    NotifierProvider.family<ReplyTargetController, ReplyTarget?, String>(
  (postId) => ReplyTargetController(postId),
);
