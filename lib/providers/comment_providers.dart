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
