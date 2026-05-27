import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notification/notification_controller.dart';
import '../notification/notification_repository.dart';
import 'supabase_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseNotificationRepository(client);
});

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
