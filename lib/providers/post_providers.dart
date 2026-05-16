import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../post/post_controller.dart';
import '../post/post_repository.dart';
import 'supabase_providers.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabasePostRepository(client);
});

final postControllerProvider =
    NotifierProvider<PostController, PostState>(PostController.new);
