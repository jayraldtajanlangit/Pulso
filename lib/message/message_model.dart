class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.body,
    this.sharedPostId,
    this.sharedPostImageUrl,
    this.sharedPostCaption,
    this.senderUsername,
    this.senderAvatarUrl,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String? body;
  final String? sharedPostId;
  final String? sharedPostImageUrl;
  final String? sharedPostCaption;
  final String? senderUsername;
  final String? senderAvatarUrl;
  final DateTime createdAt;

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final sender = map['sender'] as Map<String, dynamic>?;
    final post = map['shared_post'] as Map<String, dynamic>?;
    return MessageModel(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      body: map['body'] as String?,
      sharedPostId: map['shared_post_id'] as String?,
      sharedPostImageUrl: post?['image_url'] as String?,
      sharedPostCaption: post?['caption'] as String?,
      senderUsername: sender?['username'] as String?,
      senderAvatarUrl: sender?['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
