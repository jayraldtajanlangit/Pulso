import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/profile/profile_repository.dart';
import 'package:pulso/providers/profile_providers.dart';
import 'package:pulso/providers/services_providers.dart';
import 'package:pulso/services/image_picker_service.dart';

void main() {
  group('ProfileController (family)', () {
    ProviderContainer makeContainer({
      FakeProfileRepository? repo,
      FakeImagePickerService? picker,
    }) {
      final container = ProviderContainer.test(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            repo ?? FakeProfileRepository(),
          ),
          imagePickerServiceProvider.overrideWithValue(
            picker ?? FakeImagePickerService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('starts in loading state with no profile', () {
      final container = makeContainer();
      final state = container.read(profileControllerProvider('user-1'));

      expect(state.isLoading, isTrue);
      expect(state.profile, isNull);
      expect(state.errorMessage, isNull);
    });

    test('reload fetches profile and clears loading', () async {
      final repo = FakeProfileRepository();
      final container = makeContainer(repo: repo);

      await container
          .read(profileControllerProvider('user-1').notifier)
          .reload();

      final state = container.read(profileControllerProvider('user-1'));
      expect(state.isLoading, isFalse);
      expect(state.profile?.id, 'user-1');
      expect(state.errorMessage, isNull);
    });

    test('sets errorMessage on repository failure', () async {
      final repo = FakeProfileRepository(throwOnGet: true);
      final container = makeContainer(repo: repo);

      await container
          .read(profileControllerProvider('user-1').notifier)
          .reload();

      final state = container.read(profileControllerProvider('user-1'));
      expect(state.isLoading, isFalse);
      expect(state.profile, isNull);
      expect(state.errorMessage, isNotNull);
    });

    test('different userIds get isolated state', () async {
      final container = makeContainer();

      await container
          .read(profileControllerProvider('user-1').notifier)
          .reload();
      await container
          .read(profileControllerProvider('user-2').notifier)
          .reload();

      final s1 = container.read(profileControllerProvider('user-1'));
      final s2 = container.read(profileControllerProvider('user-2'));
      expect(s1.profile?.id, 'user-1');
      expect(s2.profile?.id, 'user-2');
    });

    test('updateProfile upserts and updates state', () async {
      final repo = FakeProfileRepository();
      final container = makeContainer(repo: repo);

      await container
          .read(profileControllerProvider('user-1').notifier)
          .reload();
      await container
          .read(profileControllerProvider('user-1').notifier)
          .updateProfile(
            displayName: 'Test User',
            username: 'testuser',
            bio: 'Hello world',
          );

      final state = container.read(profileControllerProvider('user-1'));
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
      final container = makeContainer(repo: repo, picker: picker);

      await container
          .read(profileControllerProvider('user-1').notifier)
          .reload();
      await container
          .read(profileControllerProvider('user-1').notifier)
          .pickAndUploadAvatar();

      final state = container.read(profileControllerProvider('user-1'));
      expect(state.isUploading, isFalse);
      expect(state.profile?.avatarUrl, isNotNull);
      expect(repo.uploadAvatarCalled, isTrue);
    });

    test('pickAndUploadAvatar does nothing when picker returns null', () async {
      final repo = FakeProfileRepository();
      final container = makeContainer(repo: repo);

      await container
          .read(profileControllerProvider('user-1').notifier)
          .pickAndUploadAvatar();

      expect(repo.uploadAvatarCalled, isFalse);
      expect(
        container.read(profileControllerProvider('user-1')).isUploading,
        isFalse,
      );
    });
  });
}

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
  Future<List<ProfileModel>> searchProfiles(String query) async => const [];

  @override
  Future<ProfileModel> upsertProfile(ProfileModel profile) async => profile;

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
      result == null ? const [] : [result!];
}
