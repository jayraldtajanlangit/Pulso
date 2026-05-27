import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile/profile_model.dart';

abstract class FollowRepository {
  /// Returns true if now following, false if unfollowed.
  Future<bool> toggleFollow({
    required String followerId,
    required String followingId,
  });

  Future<void> follow({
    required String followerId,
    required String followingId,
  });

  Future<void> unfollow({
    required String followerId,
    required String followingId,
  });

  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  });

  Future<int> getFollowerCount(String userId);

  Future<int> getFollowingCount(String userId);

  Future<List<String>> getFollowingIds(String userId);

  Future<List<String>> getFollowerIds(String userId);

  Future<List<ProfileModel>> getFollowingProfiles(String userId);

  Future<List<ProfileModel>> getFollowerProfiles(String userId);
}

class SupabaseFollowRepository implements FollowRepository {
  const SupabaseFollowRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> toggleFollow({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) {
      throw ArgumentError('A user cannot follow themselves.');
    }

    final existing = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
      return false;
    }

    await _client.from('follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
    return true;
  }

  @override
  Future<void> follow({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) {
      throw ArgumentError('A user cannot follow themselves.');
    }
    await _client.from('follows').insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  @override
  Future<void> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
  }

  @override
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    final response = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    return response != null;
  }

  @override
  Future<int> getFollowerCount(String userId) async {
    final response = await _client
        .from('follows')
        .select('id')
        .eq('following_id', userId)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<int> getFollowingCount(String userId) async {
    final response = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<List<String>> getFollowingIds(String userId) async {
    final response = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);

    return (response as List)
        .map((row) => (row as Map<String, dynamic>)['following_id'] as String)
        .toList();
  }

  @override
  Future<List<String>> getFollowerIds(String userId) async {
    final response = await _client
        .from('follows')
        .select('follower_id')
        .eq('following_id', userId);

    return (response as List)
        .map((row) => (row as Map<String, dynamic>)['follower_id'] as String)
        .toList();
  }

  @override
  Future<List<ProfileModel>> getFollowingProfiles(String userId) async {
    final response = await _client
        .from('follows')
        .select('profiles!following_id(id, username, display_name, avatar_url, bio, created_at, updated_at)')
        .eq('follower_id', userId);
    return (response as List)
        .map((row) => ProfileModel.fromMap(
              (row as Map<String, dynamic>)['profiles'] as Map<String, dynamic>,
            ))
        .toList();
  }

  @override
  Future<List<ProfileModel>> getFollowerProfiles(String userId) async {
    final response = await _client
        .from('follows')
        .select('profiles!follower_id(id, username, display_name, avatar_url, bio, created_at, updated_at)')
        .eq('following_id', userId);
    return (response as List)
        .map((row) => ProfileModel.fromMap(
              (row as Map<String, dynamic>)['profiles'] as Map<String, dynamic>,
            ))
        .toList();
  }
}
