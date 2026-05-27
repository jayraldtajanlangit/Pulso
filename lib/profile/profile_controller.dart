import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_repository_provider.dart';
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
  ProfileController(this.userId);

  final String userId;
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  ProfileState build() {
    if (userId.isNotEmpty) {
      Future.microtask(_load);
    }
    return const ProfileState.initial();
  }

  Future<void> _load() async {
    await loadProfile();
  }

  Future<void> loadProfile([String? targetUserId]) async {
    final id = targetUserId ?? userId;
    if (id.isEmpty) return;
    // Reset immediately so stale data from a previous profile is never shown.
    state = const ProfileState.initial();
    try {
      final profile = await _repository.getProfile(id);
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> reload() => _load();

  Future<void> updateProfile({
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

  Future<void> pickAndUploadAvatar() async {
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
