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
