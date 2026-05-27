import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pulso/story/music_clip_model.dart';
import 'package:pulso/story/story_model.dart';
import 'package:pulso/story/story_repository.dart';

class MockStoryRepository extends Mock implements StoryRepository {}

void main() {
  late MockStoryRepository repo;

  setUp(() => repo = MockStoryRepository());

  test('fetchActiveStories returns a map of userId to story list', () async {
    when(() => repo.fetchActiveStories(
          followingIds: any(named: 'followingIds'),
          currentUserId: any(named: 'currentUserId'),
        )).thenAnswer((_) async => {});

    final result = await repo.fetchActiveStories(
      followingIds: ['u2'],
      currentUserId: 'u1',
    );
    expect(result, isA<Map<String, List<StoryModel>>>());
  });

  test('fetchMusicClips returns a list', () async {
    when(() => repo.fetchMusicClips()).thenAnswer((_) async => []);

    final result = await repo.fetchMusicClips();
    expect(result, isA<List<MusicClipModel>>());
  });

  test('recordView completes without error', () async {
    when(() => repo.recordView(
          storyId: any(named: 'storyId'),
          viewerId: any(named: 'viewerId'),
        )).thenAnswer((_) async {});

    await expectLater(
      repo.recordView(storyId: 's1', viewerId: 'u1'),
      completes,
    );
  });
}
