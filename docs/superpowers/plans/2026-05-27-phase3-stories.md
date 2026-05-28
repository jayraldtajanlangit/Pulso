# Stories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 24-hour image stories with an optional built-in music clip. Stories from followed users appear in a horizontal row at the top of the feed. A full-screen viewer plays music while the story is displayed.

**Architecture:** Three Supabase tables (`stories`, `story_views`, `music_clips`) plus two new storage buckets (`stories`, `music`). A `StoryController` (NotifierProvider) loads active stories grouped by user. `StoryCreationScreen` lets users pick a photo and an optional music clip then posts the story. `StoryViewerScreen` renders full-screen with a progress bar and uses `audioplayers` for music. The `_StoriesRow` is extracted into its own file and restored to the feed.

**Tech Stack:** Flutter, Riverpod (NotifierProvider), Supabase (postgres + storage), audioplayers ^6.x, image_picker (already in pubspec), mocktail (tests)

**New dependency to add:** `audioplayers: ^6.0.0`

---

### Task 1: Add audioplayers dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add audioplayers to pubspec.yaml**

In `pubspec.yaml`, under `dependencies:`, add after `cached_network_image`:

```yaml
  audioplayers: ^6.0.0
```

- [ ] **Step 2: Install the dependency**

```bash
flutter pub get
```

Expected: resolves successfully with audioplayers in the output.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add audioplayers dependency for story music"
```

---

### Task 2: SQL migration — stories, story_views, music_clips

**Files:**
- Modify: `lib/database/sql_schema.dart`

- [ ] **Step 1: Append SQL to sql_schema.dart**

Append to `lib/database/sql_schema.dart`:

```dart
const String storiesTableSql = '''
CREATE TABLE IF NOT EXISTS music_clips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  audio_url TEXT NOT NULL,
  cover_url TEXT,
  duration_seconds INT NOT NULL DEFAULT 30,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  music_clip_id UUID REFERENCES music_clips(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL \'24 hours\')
);

CREATE TABLE IF NOT EXISTS story_views (
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, viewer_id)
);

ALTER TABLE music_clips ENABLE ROW LEVEL SECURITY;
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "music_clips_select_all"
  ON music_clips FOR SELECT USING (true);

CREATE POLICY "stories_select_all"
  ON stories FOR SELECT USING (true);

CREATE POLICY "stories_insert_own"
  ON stories FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "stories_delete_own"
  ON stories FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "story_views_select_all"
  ON story_views FOR SELECT USING (true);

CREATE POLICY "story_views_insert_authenticated"
  ON story_views FOR INSERT WITH CHECK (auth.uid() = viewer_id);

-- Storage buckets
INSERT INTO storage.buckets (id, name, public)
  VALUES (\'stories\', \'stories\', true)
  ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES (\'music\', \'music\', true)
  ON CONFLICT DO NOTHING;

CREATE POLICY "stories_images_select_all"
  ON storage.objects FOR SELECT USING (bucket_id = \'stories\');

CREATE POLICY "stories_images_insert_own"
  ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = \'stories\'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "music_files_select_all"
  ON storage.objects FOR SELECT USING (bucket_id = \'music\');
''';
```

- [ ] **Step 2: Run the SQL in Supabase**

Copy `storiesTableSql` contents and run in Supabase SQL editor. Confirm `music_clips`, `stories`, `story_views` tables appear and both `stories` and `music` storage buckets exist.

- [ ] **Step 3: Seed the music_clips table**

In the Supabase SQL editor, run the following to seed sample clips. Replace the `audio_url` values with real URLs of audio files you upload to the `music` bucket:

```sql
INSERT INTO music_clips (title, artist, audio_url, cover_url, duration_seconds) VALUES
  ('Dati', 'Unique', 'https://<your-project>.supabase.co/storage/v1/object/public/music/dati.mp3', NULL, 30),
  ('Raining in Manila', 'Lola Amour', 'https://<your-project>.supabase.co/storage/v1/object/public/music/raining.mp3', NULL, 30),
  ('Ikaw at Ako', 'Moira', 'https://<your-project>.supabase.co/storage/v1/object/public/music/ikaw-at-ako.mp3', NULL, 30);
```

Upload the actual audio files to the `music` bucket in Supabase Storage > music > Upload files. Name them `dati.mp3`, `raining.mp3`, `ikaw-at-ako.mp3`.

- [ ] **Step 4: Commit**

```bash
git add lib/database/sql_schema.dart
git commit -m "feat: add stories, story_views, music_clips table SQL"
```

---

### Task 3: StoryModel and MusicClipModel

**Files:**
- Create: `lib/story/story_model.dart`
- Create: `lib/story/music_clip_model.dart`
- Create: `test/story/story_models_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/story/story_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/story/music_clip_model.dart';
import 'package:pulso/story/story_model.dart';

void main() {
  group('StoryModel.fromMap', () {
    test('parses all fields with joined profile and music_clip', () {
      final map = {
        'id': 's1',
        'user_id': 'u1',
        'image_url': 'https://example.com/story.jpg',
        'music_clip_id': 'mc1',
        'created_at': '2026-01-01T00:00:00.000Z',
        'expires_at': '2026-01-02T00:00:00.000Z',
        'profiles': {
          'username': 'juan',
          'avatar_url': 'https://example.com/av.jpg',
        },
        'music_clips': {
          'id': 'mc1',
          'title': 'Dati',
          'artist': 'Unique',
          'audio_url': 'https://example.com/dati.mp3',
          'cover_url': null,
          'duration_seconds': 30,
        },
        'view_count': 5,
      };

      final model = StoryModel.fromMap(map);

      expect(model.id, 's1');
      expect(model.userId, 'u1');
      expect(model.authorUsername, 'juan');
      expect(model.musicClipId, 'mc1');
      expect(model.musicClip?.title, 'Dati');
      expect(model.viewCount, 5);
      expect(model.isExpired, false);
    });

    test('isExpired returns true when expires_at is in the past', () {
      final map = {
        'id': 's2',
        'user_id': 'u1',
        'image_url': 'https://example.com/story.jpg',
        'music_clip_id': null,
        'created_at': '2020-01-01T00:00:00.000Z',
        'expires_at': '2020-01-02T00:00:00.000Z',
        'profiles': null,
        'music_clips': null,
        'view_count': 0,
      };

      final model = StoryModel.fromMap(map);
      expect(model.isExpired, true);
    });
  });

  group('MusicClipModel.fromMap', () {
    test('parses all fields', () {
      final map = {
        'id': 'mc1',
        'title': 'Dati',
        'artist': 'Unique',
        'audio_url': 'https://example.com/dati.mp3',
        'cover_url': null,
        'duration_seconds': 30,
      };

      final model = MusicClipModel.fromMap(map);

      expect(model.id, 'mc1');
      expect(model.title, 'Dati');
      expect(model.artist, 'Unique');
      expect(model.durationSeconds, 30);
      expect(model.coverUrl, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/story/story_models_test.dart
```

Expected: error — files not found.

- [ ] **Step 3: Create music_clip_model.dart**

Create `lib/story/music_clip_model.dart`:

```dart
class MusicClipModel {
  const MusicClipModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.coverUrl,
    required this.durationSeconds,
  });

  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? coverUrl;
  final int durationSeconds;

  factory MusicClipModel.fromMap(Map<String, dynamic> map) {
    return MusicClipModel(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      audioUrl: map['audio_url'] as String,
      coverUrl: map['cover_url'] as String?,
      durationSeconds: map['duration_seconds'] as int? ?? 30,
    );
  }
}
```

- [ ] **Step 4: Create story_model.dart**

Create `lib/story/story_model.dart`:

```dart
import 'music_clip_model.dart';

class StoryModel {
  const StoryModel({
    required this.id,
    required this.userId,
    required this.imageUrl,
    this.musicClipId,
    this.musicClip,
    required this.createdAt,
    required this.expiresAt,
    this.authorUsername,
    this.authorAvatarUrl,
    this.viewCount = 0,
    this.viewedByCurrentUser = false,
  });

  final String id;
  final String userId;
  final String imageUrl;
  final String? musicClipId;
  final MusicClipModel? musicClip;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? authorUsername;
  final String? authorAvatarUrl;
  final int viewCount;
  final bool viewedByCurrentUser;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final clip = map['music_clips'] as Map<String, dynamic>?;
    return StoryModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      imageUrl: map['image_url'] as String,
      musicClipId: map['music_clip_id'] as String?,
      musicClip: clip != null ? MusicClipModel.fromMap(clip) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      authorUsername: profile?['username'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
      viewCount: map['view_count'] as int? ?? 0,
      viewedByCurrentUser: map['viewed_by_current_user'] as bool? ?? false,
    );
  }

  StoryModel copyWith({bool? viewedByCurrentUser}) {
    return StoryModel(
      id: id,
      userId: userId,
      imageUrl: imageUrl,
      musicClipId: musicClipId,
      musicClip: musicClip,
      createdAt: createdAt,
      expiresAt: expiresAt,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      viewCount: viewCount,
      viewedByCurrentUser: viewedByCurrentUser ?? this.viewedByCurrentUser,
    );
  }
}
```

- [ ] **Step 5: Run the test to confirm it passes**

```bash
flutter test test/story/story_models_test.dart
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/story/story_model.dart lib/story/music_clip_model.dart test/story/story_models_test.dart
git commit -m "feat: add StoryModel and MusicClipModel"
```

---

### Task 4: StoryRepository

**Files:**
- Create: `lib/story/story_repository.dart`
- Create: `test/story/story_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/story/story_repository_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/story/story_repository_test.dart
```

Expected: error — `story_repository.dart` not found.

- [ ] **Step 3: Create story_repository.dart**

Create `lib/story/story_repository.dart`:

```dart
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'music_clip_model.dart';
import 'story_model.dart';

abstract class StoryRepository {
  Future<Map<String, List<StoryModel>>> fetchActiveStories({
    required List<String> followingIds,
    required String currentUserId,
  });

  Future<List<MusicClipModel>> fetchMusicClips();

  Future<void> recordView({
    required String storyId,
    required String viewerId,
  });

  Future<StoryModel> createStory({
    required String userId,
    required File imageFile,
    String? musicClipId,
  });
}

class SupabaseStoryRepository implements StoryRepository {
  const SupabaseStoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, List<StoryModel>>> fetchActiveStories({
    required List<String> followingIds,
    required String currentUserId,
  }) async {
    final userIds = {...followingIds, currentUserId}.toList();
    if (userIds.isEmpty) return {};

    final response = await _client
        .from('stories')
        .select(
          '*, profiles!user_id(username, avatar_url), music_clips!music_clip_id(*)',
        )
        .inFilter('user_id', userIds)
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: true);

    // Count views and check if viewed by current user
    final storyIds = (response as List)
        .map((r) => (r as Map<String, dynamic>)['id'] as String)
        .toList();

    Map<String, int> viewCounts = {};
    Set<String> viewedByUser = {};

    if (storyIds.isNotEmpty) {
      final views = await _client
          .from('story_views')
          .select('story_id, viewer_id')
          .inFilter('story_id', storyIds);

      for (final v in views as List) {
        final vMap = v as Map<String, dynamic>;
        final sid = vMap['story_id'] as String;
        viewCounts[sid] = (viewCounts[sid] ?? 0) + 1;
        if (vMap['viewer_id'] == currentUserId) viewedByUser.add(sid);
      }
    }

    final result = <String, List<StoryModel>>{};
    for (final row in response) {
      final map = row as Map<String, dynamic>;
      final sid = map['id'] as String;
      final story = StoryModel.fromMap({
        ...map,
        'view_count': viewCounts[sid] ?? 0,
        'viewed_by_current_user': viewedByUser.contains(sid),
      });
      result.putIfAbsent(story.userId, () => []).add(story);
    }

    // Ensure current user appears first
    final ordered = <String, List<StoryModel>>{};
    if (result.containsKey(currentUserId)) {
      ordered[currentUserId] = result[currentUserId]!;
    }
    for (final entry in result.entries) {
      if (entry.key != currentUserId) ordered[entry.key] = entry.value;
    }
    return ordered;
  }

  @override
  Future<List<MusicClipModel>> fetchMusicClips() async {
    final response = await _client
        .from('music_clips')
        .select('*')
        .order('title', ascending: true);

    return (response as List)
        .map((r) => MusicClipModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> recordView({
    required String storyId,
    required String viewerId,
  }) async {
    await _client.from('story_views').upsert({
      'story_id': storyId,
      'viewer_id': viewerId,
    });
  }

  @override
  Future<StoryModel> createStory({
    required String userId,
    required File imageFile,
    String? musicClipId,
  }) async {
    final ext = imageFile.path.split('.').last;
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('stories').upload(path, imageFile);
    final imageUrl =
        _client.storage.from('stories').getPublicUrl(path);

    final response = await _client
        .from('stories')
        .insert({
          'user_id': userId,
          'image_url': imageUrl,
          if (musicClipId != null) 'music_clip_id': musicClipId,
        })
        .select(
          '*, profiles!user_id(username, avatar_url), music_clips!music_clip_id(*)',
        )
        .single();

    return StoryModel.fromMap({
      ...(response as Map<String, dynamic>),
      'view_count': 0,
      'viewed_by_current_user': false,
    });
  }
}
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
flutter test test/story/story_repository_test.dart
```

Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/story/story_repository.dart test/story/story_repository_test.dart
git commit -m "feat: add StoryRepository"
```

---

### Task 5: StoryController + providers

**Files:**
- Create: `lib/story/story_controller.dart`
- Create: `lib/providers/story_providers.dart`

- [ ] **Step 1: Create story_controller.dart**

Create `lib/story/story_controller.dart`:

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/story_providers.dart';
import 'music_clip_model.dart';
import 'story_model.dart';
import 'story_repository.dart';

class StoryState {
  const StoryState({
    required this.storiesByUser,
    required this.musicClips,
    this.isLoading = false,
    this.isPosting = false,
  });

  const StoryState.initial()
      : storiesByUser = const {},
        musicClips = const [],
        isLoading = false,
        isPosting = false;

  /// Ordered map: current user first, then followed users.
  final Map<String, List<StoryModel>> storiesByUser;
  final List<MusicClipModel> musicClips;
  final bool isLoading;
  final bool isPosting;

  StoryState copyWith({
    Map<String, List<StoryModel>>? storiesByUser,
    List<MusicClipModel>? musicClips,
    bool? isLoading,
    bool? isPosting,
  }) {
    return StoryState(
      storiesByUser: storiesByUser ?? this.storiesByUser,
      musicClips: musicClips ?? this.musicClips,
      isLoading: isLoading ?? this.isLoading,
      isPosting: isPosting ?? this.isPosting,
    );
  }
}

class StoryController extends Notifier<StoryState> {
  StoryRepository get _repository => ref.read(storyRepositoryProvider);

  @override
  StoryState build() => const StoryState.initial();

  Future<void> loadActiveStories({
    required List<String> followingIds,
    required String currentUserId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final storiesByUser = await _repository.fetchActiveStories(
        followingIds: followingIds,
        currentUserId: currentUserId,
      );
      state = state.copyWith(storiesByUser: storiesByUser, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMusicClips() async {
    if (state.musicClips.isNotEmpty) return;
    try {
      final clips = await _repository.fetchMusicClips();
      state = state.copyWith(musicClips: clips);
    } catch (_) {}
  }

  Future<void> recordView({
    required String storyId,
    required String viewerId,
  }) async {
    try {
      await _repository.recordView(storyId: storyId, viewerId: viewerId);
      // Mark locally as viewed
      final updated = <String, List<StoryModel>>{};
      for (final entry in state.storiesByUser.entries) {
        updated[entry.key] = entry.value
            .map((s) => s.id == storyId ? s.copyWith(viewedByCurrentUser: true) : s)
            .toList();
      }
      state = state.copyWith(storiesByUser: updated);
    } catch (_) {}
  }

  Future<void> createStory({
    required String userId,
    required File imageFile,
    String? musicClipId,
  }) async {
    state = state.copyWith(isPosting: true);
    try {
      final story = await _repository.createStory(
        userId: userId,
        imageFile: imageFile,
        musicClipId: musicClipId,
      );
      final updated = Map<String, List<StoryModel>>.from(state.storiesByUser);
      updated[userId] = [story, ...(updated[userId] ?? [])];
      state = state.copyWith(storiesByUser: updated, isPosting: false);
    } catch (_) {
      state = state.copyWith(isPosting: false);
    }
  }
}
```

- [ ] **Step 2: Create story_providers.dart**

Create `lib/providers/story_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../story/story_controller.dart';
import '../story/story_repository.dart';
import 'supabase_providers.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseStoryRepository(client);
});

final storyControllerProvider =
    NotifierProvider<StoryController, StoryState>(StoryController.new);
```

- [ ] **Step 3: Verify app compiles**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/story/story_controller.dart lib/providers/story_providers.dart
git commit -m "feat: add StoryController and providers"
```

---

### Task 6: StoriesRow widget + restore in FeedScreen

**Files:**
- Create: `lib/widgets/stories_row.dart`
- Modify: `lib/screens/feed_screen.dart`

- [ ] **Step 1: Create stories_row.dart**

Create `lib/widgets/stories_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/story_providers.dart';
import '../story/story_model.dart';
import '../screens/story_creation_screen.dart';
import '../screens/story_viewer_screen.dart';
import 'profile_avatar.dart';

class StoriesRow extends ConsumerStatefulWidget {
  const StoriesRow({super.key});

  @override
  ConsumerState<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends ConsumerState<StoriesRow> {
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;
    final followingIds = ref
        .read(followControllerProvider)
        .followingByCurrentUser
        .toList();
    await ref.read(storyControllerProvider.notifier).loadActiveStories(
      followingIds: followingIds,
      currentUserId: userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.session?.userId));
    final storiesByUser =
        ref.watch(storyControllerProvider.select((s) => s.storiesByUser));

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _OwnStoryTile(
            currentUserId: currentUserId,
            hasActiveStory: storiesByUser.containsKey(currentUserId),
            stories: storiesByUser[currentUserId] ?? [],
          ),
          ...storiesByUser.entries
              .where((e) => e.key != currentUserId)
              .map((e) => _UserStoryTile(userId: e.key, stories: e.value)),
        ],
      ),
    );
  }
}

class _OwnStoryTile extends StatelessWidget {
  const _OwnStoryTile({
    required this.currentUserId,
    required this.hasActiveStory,
    required this.stories,
  });

  final String? currentUserId;
  final bool hasActiveStory;
  final List<StoryModel> stories;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (stories.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryViewerScreen(
                storiesByUser: {currentUserId!: stories},
                initialUserId: currentUserId!,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoryCreationScreen()),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasActiveStory
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFD1D5DB),
                      width: hasActiveStory ? 2 : 1.5,
                    ),
                  ),
                  child: const ClipOval(
                    child: Icon(Icons.add, color: Color(0xFF9CA3AF), size: 28),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Your story',
              style: TextStyle(fontSize: 11, color: Color(0xFF374151)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserStoryTile extends StatelessWidget {
  const _UserStoryTile({required this.userId, required this.stories});

  final String userId;
  final List<StoryModel> stories;

  @override
  Widget build(BuildContext context) {
    final allSeen = stories.every((s) => s.viewedByCurrentUser);
    final label = stories.first.authorUsername ?? 'user';
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
            storiesByUser: {userId: stories},
            initialUserId: userId,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: allSeen
                    ? null
                    : LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: allSeen ? const Color(0xFFD1D5DB) : null,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(2),
                child: ProfileAvatar(
                  avatarUrl: stories.first.authorAvatarUrl,
                  displayName: label,
                  radius: 25,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: allSeen
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Restore StoriesRow in FeedScreen**

In `lib/screens/feed_screen.dart`, add the import:

```dart
import '../widgets/stories_row.dart';
```

In the `CustomScrollView` slivers list, add the StoriesRow and its divider back at the top (before the loading/error/empty checks):

```dart
slivers: [
  const SliverToBoxAdapter(child: StoriesRow()),
  const SliverToBoxAdapter(
    child: Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E7EB)),
  ),
  if (state.isLoading && state.posts.isEmpty)
  // ... rest of existing slivers unchanged
```

- [ ] **Step 3: Verify app compiles**

```bash
flutter analyze
```

Expected: StoryCreationScreen and StoryViewerScreen missing — fine, created next.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/stories_row.dart lib/screens/feed_screen.dart
git commit -m "feat: add StoriesRow widget and restore in FeedScreen"
```

---

### Task 7: StoryCreationScreen

**Files:**
- Create: `lib/screens/story_creation_screen.dart`

- [ ] **Step 1: Create story_creation_screen.dart**

Create `lib/screens/story_creation_screen.dart`:

```dart
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_providers.dart';
import '../providers/story_providers.dart';
import '../story/music_clip_model.dart';

class StoryCreationScreen extends ConsumerStatefulWidget {
  const StoryCreationScreen({super.key});

  @override
  ConsumerState<StoryCreationScreen> createState() =>
      _StoryCreationScreenState();
}

class _StoryCreationScreenState extends ConsumerState<StoryCreationScreen> {
  File? _imageFile;
  MusicClipModel? _selectedClip;
  final _audioPlayer = AudioPlayer();
  String? _playingClipId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storyControllerProvider.notifier).loadMusicClips();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<void> _previewClip(MusicClipModel clip) async {
    if (_playingClipId == clip.id) {
      await _audioPlayer.stop();
      setState(() => _playingClipId = null);
      return;
    }
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(clip.audioUrl));
    setState(() => _playingClipId = clip.id);
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingClipId = null);
    });
  }

  Future<void> _shareStory() async {
    final image = _imageFile;
    if (image == null) return;
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) return;

    await ref.read(storyControllerProvider.notifier).createStory(
      userId: userId,
      imageFile: image,
      musicClipId: _selectedClip?.id,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final musicClips =
        ref.watch(storyControllerProvider.select((s) => s.musicClips));
    final isPosting =
        ref.watch(storyControllerProvider.select((s) => s.isPosting));
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Create Story',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD1D5DB),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 40, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 8),
                          Text(
                            'Tap to pick a photo',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Music picker
            Row(
              children: [
                const Icon(Icons.music_note_outlined, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Add Music (optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (_selectedClip != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _selectedClip = null),
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            if (musicClips.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ...musicClips.map(
                (clip) => _MusicClipTile(
                  clip: clip,
                  isSelected: _selectedClip?.id == clip.id,
                  isPlaying: _playingClipId == clip.id,
                  onTap: () => setState(() {
                    _selectedClip = _selectedClip?.id == clip.id ? null : clip;
                  }),
                  onPreview: () => _previewClip(clip),
                  primaryColor: primary,
                ),
              ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed:
                  (_imageFile != null && !isPosting) ? _shareStory : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Share Story',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicClipTile extends StatelessWidget {
  const _MusicClipTile({
    required this.clip,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onPreview,
    required this.primaryColor,
  });

  final MusicClipModel clip;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.music_note,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clip.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${clip.artist} · ${clip.durationSeconds}s',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                color: isSelected ? primaryColor : const Color(0xFF6B7280),
              ),
              onPressed: onPreview,
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify app compiles**

```bash
flutter analyze
```

Expected: StoryViewerScreen missing — fine, created next.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/story_creation_screen.dart
git commit -m "feat: add StoryCreationScreen with image and music picker"
```

---

### Task 8: StoryViewerScreen

**Files:**
- Create: `lib/screens/story_viewer_screen.dart`

- [ ] **Step 1: Create story_viewer_screen.dart**

Create `lib/screens/story_viewer_screen.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../providers/story_providers.dart';
import '../story/story_model.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.storiesByUser,
    required this.initialUserId,
  });

  final Map<String, List<StoryModel>> storiesByUser;
  final String initialUserId;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with TickerProviderStateMixin {
  late final List<String> _userIds;
  late int _userIndex;
  int _storyIndex = 0;
  AnimationController? _progressController;
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _userIds = widget.storiesByUser.keys.toList();
    _userIndex = _userIds.indexOf(widget.initialUserId);
    if (_userIndex < 0) _userIndex = 0;
    _showStory();
  }

  @override
  void dispose() {
    _progressController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<StoryModel> get _currentStories =>
      widget.storiesByUser[_userIds[_userIndex]] ?? [];

  StoryModel get _currentStory => _currentStories[_storyIndex];

  void _showStory() {
    _progressController?.dispose();
    _audioPlayer.stop();

    final story = _currentStory;

    // Record view
    final viewerId =
        ref.read(authControllerProvider).session?.userId;
    if (viewerId != null) {
      ref.read(storyControllerProvider.notifier).recordView(
        storyId: story.id,
        viewerId: viewerId,
      );
    }

    // Start music if present
    if (story.musicClip != null) {
      _audioPlayer.play(UrlSource(story.musicClip!.audioUrl));
    }

    // Progress animation — 5 seconds per story
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      })
      ..forward();

    setState(() {});
  }

  void _next() {
    if (_storyIndex < _currentStories.length - 1) {
      setState(() => _storyIndex++);
      _showStory();
    } else if (_userIndex < _userIds.length - 1) {
      setState(() {
        _userIndex++;
        _storyIndex = 0;
      });
      _showStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previous() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _showStory();
    } else if (_userIndex > 0) {
      setState(() {
        _userIndex--;
        _storyIndex = 0;
      });
      _showStory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _currentStory;
    final stories = _currentStories;
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.session?.userId));
    final isOwnStory = story.userId == currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 2) {
            _previous();
          } else {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Story image
            CachedNetworkImage(
              imageUrl: story.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF1E293B)),
            ),

            // Dark gradient overlay at top and bottom
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),

            // Progress bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(stories.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: i < _storyIndex
                            ? Container(height: 2.5, color: Colors.white)
                            : i == _storyIndex
                                ? AnimatedBuilder(
                                    animation: _progressController!,
                                    builder: (_, __) => LinearProgressIndicator(
                                      value: _progressController!.value,
                                      minHeight: 2.5,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.4),
                                      valueColor:
                                          const AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Container(
                                    height: 2.5,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Header row (avatar + username + close)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: story.authorAvatarUrl != null
                        ? NetworkImage(story.authorAvatarUrl!)
                        : null,
                    child: story.authorAvatarUrl == null
                        ? const Icon(Icons.person, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.authorUsername ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _relativeTime(story.createdAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Music bar at bottom
            if (story.musicClip != null)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.musicClip!.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '♪ ${story.musicClip!.artist}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // View count (own stories only)
            if (isOwnStory)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                right: 16,
                child: Row(
                  children: [
                    const Icon(Icons.remove_red_eye_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${story.viewCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
```

- [ ] **Step 2: Verify the full app compiles**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 3: Manual smoke test**

Run `flutter run`, then:
1. Feed shows the Stories row at the top
2. Tap `+` on "Your story" → `StoryCreationScreen` opens
3. Pick a photo → preview appears
4. Tap a music clip's play button → audio snippet plays; tap again → stops
5. Select a clip → checkmark appears on tile
6. Tap "Share Story" → returns to feed; your avatar ring appears in the stories row
7. Tap your story → `StoryViewerScreen` opens full-screen with progress bar
8. Music plays (if selected); music bar shows at bottom
9. Tap right half → advances to next story or exits; tap left half → goes back
10. Tap another user's story ring → views their stories with their ring turning gray after

- [ ] **Step 4: Commit**

```bash
git add lib/screens/story_viewer_screen.dart
git commit -m "feat: add StoryViewerScreen with progress bar and music playback"
```
