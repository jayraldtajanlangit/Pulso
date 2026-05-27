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
        'created_at': '2026-05-28T00:00:00.000Z',
        'expires_at': '2026-05-29T00:00:00.000Z',
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
