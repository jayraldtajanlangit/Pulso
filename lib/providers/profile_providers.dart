import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_controller.dart';

export 'profile_repository_provider.dart';

final profileControllerProvider =
    NotifierProvider.family<ProfileController, ProfileState, String>(
      (userId) => ProfileController(userId),
    );
