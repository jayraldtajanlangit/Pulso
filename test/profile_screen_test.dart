import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/profile/profile_model.dart';
import 'package:pulso/profile/profile_repository.dart';
import 'package:pulso/providers/profile_providers.dart';
import 'package:pulso/providers/services_providers.dart';
import 'package:pulso/screens/edit_profile_screen.dart';
import 'package:pulso/services/image_picker_service.dart';

void main() {
  Widget buildScreen({
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

  testWidgets('shows loading indicator before profile loads', (tester) async {
    await tester.pumpWidget(buildScreen(userId: 'user-1'));

    // Before microtask runs, loading indicator is shown.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows avatar and form fields after profile loads', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(userId: 'user-1'));
    await tester.pumpAndSettle(); // allow loadProfile microtask + setState

    expect(find.byKey(const Key('profileAvatar')), findsOneWidget);
    expect(find.byKey(const Key('displayNameField')), findsOneWidget);
    expect(find.byKey(const Key('usernameField')), findsOneWidget);
    expect(find.byKey(const Key('bioField')), findsOneWidget);
    expect(find.byKey(const Key('saveProfileButton')), findsOneWidget);
  });

  testWidgets('pre-fills text fields with existing profile data', (
    tester,
  ) async {
    final repo = FakeProfileRepository(
      profile: ProfileModel(
        id: 'user-1',
        displayName: 'Jane Doe',
        username: 'janedoe',
        bio: 'Flutter dev',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );

    await tester.pumpWidget(buildScreen(userId: 'user-1', repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('janedoe'), findsOneWidget);
    expect(find.text('Flutter dev'), findsOneWidget);
  });

  testWidgets('save button triggers updateProfile', (tester) async {
    final repo = FakeProfileRepository();
    await tester.pumpWidget(buildScreen(userId: 'user-1', repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('displayNameField')),
      'New Name',
    );
    await tester.tap(find.byKey(const Key('saveProfileButton')));
    await tester.pumpAndSettle();

    expect(repo.upsertCalled, isTrue);
  });

  testWidgets('upload avatar button is present', (tester) async {
    await tester.pumpWidget(buildScreen(userId: 'user-1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('uploadAvatarButton')), findsOneWidget);
  });

  testWidgets('shows error message when repository fails', (tester) async {
    final repo = FakeProfileRepository(throwOnGet: true);
    await tester.pumpWidget(buildScreen(userId: 'user-1', repo: repo));
    await tester.pumpAndSettle();

    // Loading stops and error shows.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('network error'), findsOneWidget);
  });
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({ProfileModel? profile, this.throwOnGet = false})
    : _profile = profile;

  ProfileModel? _profile;
  final bool throwOnGet;
  bool upsertCalled = false;

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
  Future<List<ProfileModel>> searchProfiles(String query) async => const [];

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
  ) async => 'https://example.com/$userId/avatar.jpg';
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
