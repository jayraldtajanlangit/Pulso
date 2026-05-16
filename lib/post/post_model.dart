class PostModel {
  const PostModel({
    required this.id,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) => PostModel(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    content: map['content'] as String,
    imageUrl: map['image_url'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );

  final String id;
  final String userId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toInsertMap() => {
    'user_id': userId,
    'content': content,
    if (imageUrl != null) 'image_url': imageUrl,
  };
}
