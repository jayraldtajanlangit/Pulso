import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../story/story_controller.dart';
import '../story/story_repository.dart';
import 'supabase_providers.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseStoryRepository(client);
});

final storyControllerProvider =
    NotifierProvider<StoryController, StoryState>(StoryController.new);
