import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/post/post_model.dart';
import 'package:pulso/post/post_repository.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/profile/profile_repository.dart';
import 'package:pulso/providers/post_providers.dart';
import 'package:pulso/providers/profile_providers.dart';
import 'package:pulso/providers/services_providers.dart';
import 'package:pulso/screens/edit_profile_screen.dart';
import 'package:pulso/screens/profile_screen.dart';
import 'package:pulso/services/image_picker_service.dart';

void main() {
  Widget buildProfileScreen({
    required String userId,
    bool isOwnProfile = false,
    FakeProfileRepository? repo,
    FakeImagePickerService? picker,
  }) {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          repo ?? FakeProfileRepository(),
        ),
        imagePickerServiceProvider.overrideWithValue(
          picker ?? FakeImagePickerService(),
        ),
        postRepositoryProvider.overrideWithValue(FakePostRepository()),
      ],
    );

    addTearDown(container.dispose);

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: ProfileScreen(userId: userId, isOwnProfile: isOwnProfile),
      ),
    );
  }

  Widget buildEditProfileScreen({
    required String userId,
    FakeProfileRepository? repo,
    FakeImagePickerService? picker,
  }) {
    final container = ProviderContainer(
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

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: EditProfileScreen(userId: userId)),
    );
  }

  group('ProfileScreen', () {
    testWidgets('shows loading indicator before profile loads', (tester) async {
      await tester.pumpWidget(buildProfileScreen(userId: 'user-1'));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows profile header after profile loads', (tester) async {
      final repo = FakeProfileRepository(profile: _janeProfile());

      await tester.pumpWidget(buildProfileScreen(userId: 'user-1', repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profileAvatar')), findsOneWidget);
      expect(find.text('Jane Doe'), findsNWidgets(2));
      expect(find.text('Flutter dev'), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('shows edit profile action for own profile', (tester) async {
      await tester.pumpWidget(
        buildProfileScreen(userId: 'user-1', isOwnProfile: true),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('editProfileButton')), findsOneWidget);
    });

    testWidgets('shows error message when repository fails', (tester) async {
      final repo = FakeProfileRepository(throwOnGet: true);
      await tester.pumpWidget(buildProfileScreen(userId: 'user-1', repo: repo));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('network error'), findsOneWidget);
    });
  });

  group('EditProfileScreen', () {
    testWidgets('shows avatar and form fields after profile loads', (
      tester,
    ) async {
      await tester.pumpWidget(buildEditProfileScreen(userId: 'user-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profileAvatar')), findsOneWidget);
      expect(find.byKey(const Key('uploadAvatarButton')), findsOneWidget);
      expect(find.byKey(const Key('displayNameField')), findsOneWidget);
      expect(find.byKey(const Key('usernameField')), findsOneWidget);
      expect(find.byKey(const Key('bioField')), findsOneWidget);
      expect(find.byKey(const Key('saveProfileButton')), findsOneWidget);
    });

    testWidgets('pre-fills text fields with existing profile data', (
      tester,
    ) async {
      final repo = FakeProfileRepository(profile: _janeProfile());

      await tester.pumpWidget(
        buildEditProfileScreen(userId: 'user-1', repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Jane Doe'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'janedoe'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Flutter dev'), findsOneWidget);
    });

    testWidgets('save button triggers updateProfile', (tester) async {
      final repo = FakeProfileRepository();
      await tester.pumpWidget(
        buildEditProfileScreen(userId: 'user-1', repo: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('displayNameField')),
        'New Name',
      );
      await tester.tap(find.byKey(const Key('saveProfileButton')));
      await tester.pumpAndSettle();

      expect(repo.upsertCalled, isTrue);
      expect(repo.profile?.displayName, 'New Name');
    });

    testWidgets('upload avatar button uploads avatar', (tester) async {
      final repo = FakeProfileRepository();
      final picker = FakeImagePickerService(
        result: (bytes: Uint8List.fromList([1, 2, 3]), mimeType: 'image/jpeg'),
      );
      await tester.pumpWidget(
        buildEditProfileScreen(userId: 'user-1', repo: repo, picker: picker),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('uploadAvatarButton')));
      await tester.pumpAndSettle();

      expect(repo.uploadAvatarCalled, isTrue);
      expect(repo.profile?.avatarUrl, 'https://example.com/user-1/avatar.jpg');
    });

    testWidgets('shows error message when repository fails', (tester) async {
      final repo = FakeProfileRepository(throwOnGet: true);
      await tester.pumpWidget(
        buildEditProfileScreen(userId: 'user-1', repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('network error'), findsOneWidget);
    });
  });
}

ProfileModel _janeProfile() => ProfileModel(
  id: 'user-1',
  displayName: 'Jane Doe',
  username: 'janedoe',
  bio: 'Flutter dev',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({ProfileModel? profile, this.throwOnGet = false})
    : _profile = profile;

  ProfileModel? get profile => _profile;

  ProfileModel? _profile;
  final bool throwOnGet;
  bool upsertCalled = false;
  bool uploadAvatarCalled = false;

  @override
  Future<ProfileModel?> getProfile(String userId) async {
    if (throwOnGet) throw Exception('network error');
    return _profile ??
        ProfileModel(
          id: userId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );
  }

  @override
  Future<ProfileModel> upsertProfile(ProfileModel profile) async {
    upsertCalled = true;
    _profile = profile;
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
}

class FakePostRepository implements PostRepository {
  @override
  Future<List<PostModel>> getPosts(String userId) async => const [];

  @override
  Future<PostModel> createPost(PostModel post) async => post;

  @override
  Future<String> uploadPostImage(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async => 'https://example.com/$userId/post.jpg';
}
