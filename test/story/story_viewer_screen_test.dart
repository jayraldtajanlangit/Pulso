import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/auth/auth_repository.dart';
import 'package:pulso/providers/auth_providers.dart';
import 'package:pulso/providers/story_providers.dart';
import 'package:pulso/screens/story_viewer_screen.dart';
import 'package:pulso/story/music_clip_model.dart';
import 'package:pulso/story/story_model.dart';
import 'package:pulso/story/story_repository.dart';

void main() {
  testWidgets('holding the story pauses progress until released', (
    tester,
  ) async {
    await _pumpViewer(tester, repository: _FakeStoryRepository());

    final initialProgress = _progressValue(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StoryViewerScreen)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(_progressValue(tester), initialProgress);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(_progressValue(tester), greaterThan(initialProgress));
  });

  testWidgets('own story view count opens the viewer list', (tester) async {
    final repository = _FakeStoryRepository(
      viewers: [
        StoryViewerModel(
          viewerId: 'viewer-1',
          viewedAt: DateTime.parse('2026-05-28T01:30:00.000Z'),
          username: 'alice',
        ),
      ],
    );

    await _pumpViewer(tester, repository: repository);

    await tester.tap(find.byKey(const Key('story-view-count-button')));
    await tester.pumpAndSettle();

    expect(find.text('Viewed by'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(repository.fetchStoryViewersCalls, 1);
  });
}

Future<void> _pumpViewer(
  WidgetTester tester, {
  required _FakeStoryRepository repository,
}) async {
  final authRepository = _StubAuthRepository();
  final storiesByUser = {
    'me': [
      StoryModel(
        id: 'story-1',
        userId: 'me',
        imageUrl: 'https://example.com/story.jpg',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().add(const Duration(hours: 23)),
        authorUsername: 'me',
        viewCount: 1,
      ),
    ],
  };

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        storyRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: StoryViewerScreen(
          storiesByUser: storiesByUser,
          initialUserId: 'me',
        ),
      ),
    ),
  );
  await tester.pump();

  addTearDown(authRepository.dispose);
}

double _progressValue(WidgetTester tester) {
  return tester
      .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .value!;
}

class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository() {
    _controller.add(_session);
  }

  final _controller = StreamController<AppAuthSession?>.broadcast();
  final _session = const AppAuthSession(userId: 'me', email: 'me@example.com');

  @override
  AppAuthSession? get currentSession => _session;

  @override
  Stream<AppAuthSession?> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  void dispose() {
    _controller.close();
  }
}

class _FakeStoryRepository implements StoryRepository {
  _FakeStoryRepository({this.viewers = const []});

  final List<StoryViewerModel> viewers;
  int fetchStoryViewersCalls = 0;

  @override
  Future<StoryModel> createStory({
    required String userId,
    required File imageFile,
    String? musicClipId,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, List<StoryModel>>> fetchActiveStories({
    required List<String> followingIds,
    required String currentUserId,
  }) async => const {};

  @override
  Future<List<MusicClipModel>> fetchMusicClips() async => const [];

  @override
  Future<List<StoryViewerModel>> fetchStoryViewers({
    required String storyId,
  }) async {
    fetchStoryViewersCalls++;
    return viewers;
  }

  @override
  Future<void> recordView({
    required String storyId,
    required String viewerId,
  }) async {}

  @override
  Future<bool> toggleReaction({
    required String storyId,
    required String userId,
  }) async => true;
}
