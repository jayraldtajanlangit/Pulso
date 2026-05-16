import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_providers.dart';
import '../providers/services_providers.dart';
import 'profile_model.dart';
import 'profile_repository.dart';

class ProfileState {
  const ProfileState({
    required this.isLoading,
    required this.isUploading,
    this.profile,
    this.errorMessage,
  });

  const ProfileState.initial()
    : isLoading = true,
      isUploading = false,
      profile = null,
      errorMessage = null;

  final bool isLoading;
  final bool isUploading;
  final ProfileModel? profile;
  final String? errorMessage;

  ProfileState copyWith({
    bool? isLoading,
    bool? isUploading,
    ProfileModel? profile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState.initial();

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  Future<void> loadProfile(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repository.getProfile(userId);
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? username,
    String? displayName,
    String? bio,
  }) async {
    final current = state.profile;
    final updated = ProfileModel(
      id: userId,
      username: username ?? current?.username,
      displayName: displayName ?? current?.displayName,
      bio: bio ?? current?.bio,
      avatarUrl: current?.avatarUrl,
      createdAt: current?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final saved = await _repository.upsertProfile(updated);
      state = state.copyWith(isLoading: false, profile: saved);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> pickAndUploadAvatar(String userId) async {
    final picked = await ref.read(imagePickerServiceProvider).pickImage();
    if (picked == null) return;

    state = state.copyWith(isUploading: true, clearError: true);
    try {
      final url = await _repository.uploadAvatar(
        userId,
        picked.bytes,
        picked.mimeType,
      );
      final current = state.profile;
      final updated = ProfileModel(
        id: userId,
        username: current?.username,
        displayName: current?.displayName,
        bio: current?.bio,
        avatarUrl: url,
        createdAt: current?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final saved = await _repository.upsertProfile(updated);
      state = state.copyWith(isUploading: false, profile: saved);
    } catch (e) {
      state = state.copyWith(isUploading: false, errorMessage: e.toString());
    }
  }
}
