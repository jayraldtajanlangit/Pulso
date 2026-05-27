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
      final map = row;
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
    final imageUrl = _client.storage.from('stories').getPublicUrl(path);

    final response = await _client
        .from('stories')
        .insert({
          'user_id': userId,
          'image_url': imageUrl,
          'music_clip_id': musicClipId,
        })
        .select(
          '*, profiles!user_id(username, avatar_url), music_clips!music_clip_id(*)',
        )
        .single();

    return StoryModel.fromMap({
      ...response,
      'view_count': 0,
      'viewed_by_current_user': false,
    });
  }
}
