class PostModel {
  const PostModel({
    required this.id,
    required this.userId,
    required this.caption,
    required this.imageUrl,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    final author = map['profiles'] as Map<String, dynamic>?;
    final primaryUrl = map['image_url'] as String;

    final rawImages = map['post_images'] as List?;
    List<String> imageUrls;
    if (rawImages != null && rawImages.isNotEmpty) {
      final sorted = List<Map<String, dynamic>>.from(
        rawImages.map((e) => e as Map<String, dynamic>),
      )..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
      imageUrls = sorted.map((e) => e['image_url'] as String).toList();
    } else {
      imageUrls = [primaryUrl];
    }

    return PostModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      caption: (map['caption'] as String?) ?? '',
      imageUrl: primaryUrl,
      imageUrls: imageUrls,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      likeCount: _readCount(map['like_count']),
      commentCount: _readCount(map['comment_count']),
      authorUsername: author?['username'] as String?,
      authorDisplayName: author?['display_name'] as String?,
      authorAvatarUrl: author?['avatar_url'] as String?,
    );
  }

  static int _readCount(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  final String id;
  final String userId;
  final String caption;

  /// Primary image (first image, kept for backward compat with posts.image_url).
  final String imageUrl;

  /// All images in order (from post_images table, falls back to [imageUrl]).
  final List<String> imageUrls;

  final DateTime createdAt;
  final DateTime updatedAt;
  final int likeCount;
  final int commentCount;

  final String? authorUsername;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  Map<String, dynamic> toInsertMap() => {
    'user_id': userId,
    'caption': caption,
    'image_url': imageUrl,
  };

  PostModel copyWith({
    int? likeCount,
    int? commentCount,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      caption: caption,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      createdAt: createdAt,
      updatedAt: updatedAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      authorUsername: authorUsername ?? this.authorUsername,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }
}
