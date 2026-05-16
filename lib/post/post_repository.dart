import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'post_model.dart';

abstract class PostRepository {
  Future<List<PostModel>> getPosts(String userId);

  Future<PostModel> createPost(PostModel post);

  Future<String> uploadPostImage(
    String userId,
    Uint8List bytes,
    String mimeType,
  );
}

class SupabasePostRepository implements PostRepository {
  const SupabasePostRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PostModel>> getPosts(String userId) async {
    final response = await _client
        .from('posts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => PostModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PostModel> createPost(PostModel post) async {
    final response =
        await _client
            .from('posts')
            .insert(post.toInsertMap())
            .select()
            .single();
    return PostModel.fromMap(response);
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
