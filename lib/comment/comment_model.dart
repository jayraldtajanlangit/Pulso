class CommentModel {
  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    final author = map['profiles'] as Map<String, dynamic>?;
    return CommentModel(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      body: map['body'] as String,
      createdAt: _parseDate(map['created_at']),
      authorUsername: author?['username'] as String?,
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
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

  /// Joined from profiles table when available.
  final String? authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  Map<String, dynamic> toInsertMap() => {
    'post_id': postId,
    'user_id': userId,
    'body': body,
  };

  CommentModel copyWith({
    String? id,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId,
      userId: userId,
      body: body,
      createdAt: createdAt,
      authorUsername: authorUsername ?? this.authorUsername,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }
}
