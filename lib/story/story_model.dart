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
    this.isLikedByMe = false,
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

  /// True if the current viewer has reacted (hearted) this story.
  final bool isLikedByMe;

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
      isLikedByMe: map['is_liked_by_me'] as bool? ?? false,
    );
  }

  StoryModel copyWith({bool? viewedByCurrentUser, bool? isLikedByMe}) {
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
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}

class StoryViewerModel {
  const StoryViewerModel({
    required this.viewerId,
    required this.viewedAt,
    this.username,
    this.avatarUrl,
  });

  final String viewerId;
  final DateTime viewedAt;
  final String? username;
  final String? avatarUrl;

  factory StoryViewerModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return StoryViewerModel(
      viewerId: map['viewer_id'] as String,
      viewedAt: DateTime.parse(map['viewed_at'] as String),
      username: profile?['username'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
