import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'post_model.dart';

abstract class PostRepository {
  /// Fetch a user-scoped list (used on profile screens).
  Future<List<PostModel>> getPosts(String userId);

  /// Fetch the global feed (all posts, reverse-chronological).
  Future<List<PostModel>> getFeed({int limit = 20, int offset = 0});

  Future<PostModel> createPost(PostModel post);

  Future<void> deletePost(String postId);

  Future<String> uploadPostImage(
    String userId,
    Uint8List bytes,
    String mimeType,
  );
}

class SupabasePostRepository implements PostRepository {
  const SupabasePostRepository(this._client);

  final SupabaseClient _client;

  static const _selectWithAuthor =
      '*, profiles:user_id(username, display_name, avatar_url)';

  @override
  Future<List<PostModel>> getPosts(String userId) async {
    final response = await _client
        .from('posts')
        .select(_selectWithAuthor)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => PostModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<PostModel>> getFeed({int limit = 20, int offset = 0}) async {
    final response = await _client
        .from('posts')
        .select(_selectWithAuthor)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (response as List)
        .map((e) => PostModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PostModel> createPost(PostModel post) async {
    final response = await _client
        .from('posts')
        .insert(post.toInsertMap())
        .select(_selectWithAuthor)
        .single();
    return PostModel.fromMap(response);
  }

  @override
  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
  }

  @override
  Future<String> uploadPostImage(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}';
    await _client.storage.from('posts').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );
    return _client.storage.from('posts').getPublicUrl(path);
  }
}
