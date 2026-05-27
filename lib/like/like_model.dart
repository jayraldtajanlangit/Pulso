class LikeModel {
  const LikeModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.createdAt,
  });

  factory LikeModel.fromMap(Map<String, dynamic> map) => LikeModel(
    id: map['id'] as String,
    postId: map['post_id'] as String,
    userId: map['user_id'] as String,
    createdAt: _parseDate(map['created_at']),
  );

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
  final DateTime createdAt;

  Map<String, dynamic> toInsertMap() => {
    'post_id': postId,
    'user_id': userId,
  };
}
