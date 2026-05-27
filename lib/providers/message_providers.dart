import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../message/message_controller.dart';
import '../message/message_repository.dart';
import 'supabase_providers.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseMessageRepository(client);
});

final messageControllerProvider =
    NotifierProvider<MessageController, MessageState>(MessageController.new);
