class CommentModel {
  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.parentCommentId,
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.likeCount = 0,
    this.isLikedByMe = false,
    this.replyCount = 0,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    final author = map['profiles'] as Map<String, dynamic>?;
    return CommentModel(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      body: map['body'] as String,
      createdAt: _parseDate(map['created_at']),
      parentCommentId: map['parent_comment_id'] as String?,
      authorUsername: author?['username'] as String?,
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
      likeCount: (map['like_count'] as int?) ?? 0,
      isLikedByMe: (map['is_liked_by_me'] as bool?) ?? false,
      replyCount: (map['reply_count'] as int?) ?? 0,
    );
  }

  static DateTime _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  final String id;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String? parentCommentId;

  /// Joined from profiles table when available.
  final String? authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  /// Hydrated client-side.
  final int likeCount;
  final bool isLikedByMe;
  final int replyCount;

  bool get isReply => parentCommentId != null;

  Map<String, dynamic> toInsertMap() => {
    'post_id': postId,
    'user_id': userId,
    'body': body,
    if (parentCommentId != null) 'parent_comment_id': parentCommentId,
  };

  CommentModel copyWith({
    String? id,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
    int? likeCount,
    bool? isLikedByMe,
    int? replyCount,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId,
      userId: userId,
      body: body,
      createdAt: createdAt,
      parentCommentId: parentCommentId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      replyCount: replyCount ?? this.replyCount,
    );
  }
}
