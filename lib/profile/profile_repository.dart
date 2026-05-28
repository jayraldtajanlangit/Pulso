import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel?> getProfile(String userId);

  Future<List<ProfileModel>> searchProfiles(String query);

  Future<ProfileModel> upsertProfile(ProfileModel profile);

  Future<String> uploadAvatar(String userId, Uint8List bytes, String mimeType);
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ProfileModel?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) return null;
    return ProfileModel.fromMap(response);
  }

  @override
  Future<List<ProfileModel>> searchProfiles(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final safeQuery = trimmed.replaceAll(',', ' ');
    final response = await _client
        .from('profiles')
        .select()
        .or('username.ilike.%$safeQuery%,display_name.ilike.%$safeQuery%')
        .limit(20);

    return (response as List)
        .map((row) => ProfileModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProfileModel> upsertProfile(ProfileModel profile) async {
    final response = await _client
        .from('profiles')
        .upsert(profile.toMap())
        .select()
        .single();
    return ProfileModel.fromMap(response);
  }

  @override
  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async {
    final path = '$userId/avatar';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    // Bust cache by appending a timestamp query param.
    final base = _client.storage.from('avatars').getPublicUrl(path);
    return '$base?t=${DateTime.now().millisecondsSinceEpoch}';
  }
}
