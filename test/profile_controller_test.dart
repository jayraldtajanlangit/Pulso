import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/profile/profile_repository.dart';
import 'package:pulso/providers/profile_providers.dart';
import 'package:pulso/providers/services_providers.dart';
import 'package:pulso/services/image_picker_service.dart';

void main() {
  group('ProfileController', () {
    test('starts in loading state with no profile', () {
      final container = ProviderContainer.test(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          imagePickerServiceProvider.overrideWithValue(
            FakeImagePickerService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(profileControllerProvider);

      expect(state.isLoading, isTrue);
      expect(state.profile, isNull);
      expect(state.errorMessage, isNull);
    });

    test('loadProfile fetches profile and clears loading', () async {
      final repo = FakeProfileRepository();
      final container = ProviderContainer.test(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(
            FakeImagePickerService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(profileControllerProvider.notifier)
          .loadProfile('user-1');

      final state = container.read(profileControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.profile?.id, 'user-1');
      expect(state.errorMessage, isNull);
    });

    test('loadProfile sets errorMessage on repository failure', () async {
      final repo = FakeProfileRepository(throwOnGet: true);
      final container = ProviderContainer.test(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(
            FakeImagePickerService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(profileControllerProvider.notifier)
          .loadProfile('user-1');

      final state = container.read(profileControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.profile, isNull);
      expect(state.errorMessage, isNotNull);
    });

    test('updateProfile upserts and updates state', () async {
      final repo = FakeProfileRepository();
      final container = ProviderContainer.test(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(
            FakeImagePickerService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(profileControllerProvider.notifier).updateProfile(
        userId: 'user-1',
        displayName: 'Test User',
        username: 'testuser',
        bio: 'Hello world',
      );

      final state = container.read(profileControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.profile?.displayName, 'Test User');
      expect(state.profile?.username, 'testuser');
      expect(state.profile?.bio, 'Hello world');
    });

    test('pickAndUploadAvatar uploads and saves new avatar URL', () async {
      final repo = FakeProfileRepository();
      final picker = FakeImagePickerService(
        result: (bytes: Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg'),
      );
      final container = ProviderContainer.test(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(picker),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(profileControllerProvider.notifier)
          .pickAndUploadAvatar('user-1');

      final state = container.read(profileControllerProvider);
      expect(state.isUploading, isFalse);
      expect(state.profile?.avatarUrl, isNotNull);
      expect(repo.uploadAvatarCalled, isTrue);
    });

    test('pickAndUploadAvatar does nothing when picker returns null', () async {
      final repo = FakeProfileRepository();
      final picker = FakeImagePickerService();
      final container = ProviderContainer.test(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          imagePickerServiceProvider.overrideWithValue(picker),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(profileControllerProvider.notifier)
          .pickAndUploadAvatar('user-1');

      expect(repo.uploadAvatarCalled, isFalse);
      expect(container.read(profileControllerProvider).isUploading, isFalse);
    });
  });
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.throwOnGet = false});

  final bool throwOnGet;
  bool uploadAvatarCalled = false;

  @override
  Future<ProfileModel?> getProfile(String userId) async {
    if (throwOnGet) throw Exception('network error');
    return ProfileModel(
      id: userId,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
  }

  @override
  Future<ProfileModel> upsertProfile(ProfileModel profile) async {
    return profile;
  }

  @override
  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async {
    uploadAvatarCalled = true;
    return 'https://example.com/$userId/avatar.jpg';
  }
}

class FakeImagePickerService implements ImagePickerService {
  FakeImagePickerService({this.result});

  final PickedImage? result;

  @override
  Future<PickedImage?> pickImage() async => result;

  @override
  Future<List<PickedImage>> pickMultipleImages() async =>
      result != null ? [result!] : [];
}
