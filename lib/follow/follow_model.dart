class FollowModel {
  const FollowModel({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  factory FollowModel.fromMap(Map<String, dynamic> map) => FollowModel(
    id: map['id'] as String,
    followerId: map['follower_id'] as String,
    followingId: map['following_id'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  final String id;
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  Map<String, dynamic> toInsertMap() => {
    'follower_id': followerId,
    'following_id': followingId,
  };
}
