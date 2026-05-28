class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    this.postId,
    this.storyId,
    required this.read,
    required this.createdAt,
    this.actorUsername,
    this.actorAvatarUrl,
    this.postImageUrl,
    this.storyImageUrl,
  });

  final String id;
  final String recipientId;
  final String actorId;
  final String type; // 'like' | 'comment' | 'follow' | 'story_like'
  final String? postId;
  final String? storyId;
  final bool read;
  final DateTime createdAt;
  final String? actorUsername;
  final String? actorAvatarUrl;
  final String? postImageUrl;
  final String? storyImageUrl;

  /// Convenience: the thumbnail image to render alongside the notification,
  /// regardless of whether it points at a post or a story.
  String? get thumbnailImageUrl => postImageUrl ?? storyImageUrl;

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final actor = map['actor'] as Map<String, dynamic>?;
    final post = map['post'] as Map<String, dynamic>?;
    final story = map['story'] as Map<String, dynamic>?;
    return NotificationModel(
      id: map['id'] as String,
      recipientId: map['recipient_id'] as String,
      actorId: map['actor_id'] as String,
      type: map['type'] as String,
      postId: map['post_id'] as String?,
      storyId: map['story_id'] as String?,
      read: map['read'] as bool? ?? false,
      createdAt: _parseDate(map['created_at']),
      actorUsername: actor?['username'] as String?,
      actorAvatarUrl: actor?['avatar_url'] as String?,
      postImageUrl: post?['image_url'] as String?,
      storyImageUrl: story?['image_url'] as String?,
    );
  }

  static DateTime _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  NotificationModel copyWith({bool? read}) {
    return NotificationModel(
      id: id,
      recipientId: recipientId,
      actorId: actorId,
      type: type,
      postId: postId,
      storyId: storyId,
      read: read ?? this.read,
      createdAt: createdAt,
      actorUsername: actorUsername,
      actorAvatarUrl: actorAvatarUrl,
      postImageUrl: postImageUrl,
      storyImageUrl: storyImageUrl,
    );
  }
}
