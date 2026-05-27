class ProfileModel {
  const ProfileModel({
    required this.id,
    this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) => ProfileModel(
    id: map['id'] as String,
    username: map['username'] as String?,
    displayName: map['display_name'] as String?,
    bio: map['bio'] as String?,
    avatarUrl: map['avatar_url'] as String?,
    createdAt: _parseDate(map['created_at']),
    updatedAt: _parseDate(map['updated_at']),
  );

  static DateTime _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  final String id;
  final String? username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    if (username != null) 'username': username,
    if (displayName != null) 'display_name': displayName,
    if (bio != null) 'bio': bio,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  };

  ProfileModel copyWith({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    DateTime? updatedAt,
    bool clearUsername = false,
    bool clearDisplayName = false,
    bool clearBio = false,
    bool clearAvatarUrl = false,
  }) {
    return ProfileModel(
      id: id,
      username: clearUsername ? null : username ?? this.username,
      displayName: clearDisplayName ? null : displayName ?? this.displayName,
      bio: clearBio ? null : bio ?? this.bio,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
