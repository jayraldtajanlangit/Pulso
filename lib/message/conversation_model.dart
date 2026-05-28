class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.otherUserId,
    this.otherUsername,
    this.otherAvatarUrl,
    this.lastMessageBody,
    this.lastMessageIsOwn = false,
    this.unreadCount = 0,
    required this.lastMessageAt,
    required this.createdAt,
  });

  final String id;
  final String otherUserId;
  final String? otherUsername;
  final String? otherAvatarUrl;
  final String? lastMessageBody;
  final bool lastMessageIsOwn;
  final int unreadCount;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    final other = map['other_user'] as Map<String, dynamic>?;
    return ConversationModel(
      id: map['id'] as String,
      otherUserId: other?['id'] as String? ?? '',
      otherUsername: _profileName(other),
      otherAvatarUrl: other?['avatar_url'] as String?,
      lastMessageBody: map['last_message_body'] as String?,
      lastMessageIsOwn: map['last_message_is_own'] as bool? ?? false,
      unreadCount: map['unread_count'] as int? ?? 0,
      lastMessageAt: DateTime.parse(map['last_message_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

String? _profileName(Map<String, dynamic>? profile) {
  final username = profile?['username'] as String?;
  if (username != null && username.trim().isNotEmpty) return username;

  final displayName = profile?['display_name'] as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName;
  }

  return null;
}
