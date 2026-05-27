import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'post_model.dart';

abstract class PostRepository {
  /// Fetch a user-scoped list (used on profile screens).
  Future<List<PostModel>> getPosts(String userId);

  /// Fetch the global feed (all posts, reverse-chronological).
  Future<List<PostModel>> fetchFeed({int limit = 20, int offset = 0});

  /// Fetch feed filtered to posts by users the current user follows.
  Future<List<PostModel>> fetchFollowingFeed({
    required List<String> followingIds,
    int limit = 20,
    int offset = 0,
  });

  Future<PostModel> createPost(PostModel post, {List<String> extraImageUrls});

  Future<PostModel> updatePost(String postId, {required String caption});

  Future<void> deletePost(String postId);

  Future<String> uploadPostImage(
    String userId,
    Uint8List bytes,
    String mimeType,
  );

  Future<List<PostModel>> getPostsByIds(List<String> postIds);

  Future<List<String>> uploadPostImages(
    String userId,
    List<({Uint8List bytes, String mimeType})> images,
  );
}

class SupabasePostRepository implements PostRepository {
  const SupabasePostRepository(this._client);

  final SupabaseClient _client;

  static const _selectWithAuthor =
      '*, profiles!user_id(username, display_name, avatar_url), post_images(image_url, position)';

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
  Future<List<PostModel>> fetchFeed({int limit = 20, int offset = 0}) async {
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
  Future<List<PostModel>> fetchFollowingFeed({
    required List<String> followingIds,
    int limit = 20,
    int offset = 0,
  }) async {
    if (followingIds.isEmpty) return [];
    final response = await _client
        .from('posts')
        .select(_selectWithAuthor)
        .inFilter('user_id', followingIds)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (response as List)
        .map((e) => PostModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PostModel> createPost(
    PostModel post, {
    List<String> extraImageUrls = const [],
  }) async {
    final response = await _client
        .from('posts')
        .insert(post.toInsertMap())
        .select('id')
        .single();
    final postId = response['id'] as String;

    final allUrls = [post.imageUrl, ...extraImageUrls];
    await _client.from('post_images').insert([
      for (var i = 0; i < allUrls.length; i++)
        {'post_id': postId, 'image_url': allUrls[i], 'position': i},
    ]);

    final full = await _client
        .from('posts')
        .select(_selectWithAuthor)
        .eq('id', postId)
        .single();
    return PostModel.fromMap(full);
  }

  @override
  Future<List<String>> uploadPostImages(
    String userId,
    List<({Uint8List bytes, String mimeType})> images,
  ) async {
    final base = DateTime.now().millisecondsSinceEpoch;
    final urls = await Future.wait(
      images.indexed.map(
        (entry) => _uploadWithPath(
          '$userId/${base}_${entry.$1}',
          entry.$2.bytes,
          entry.$2.mimeType,
        ),
      ),
    );
    return urls;
  }

  Future<String> _uploadWithPath(
    String path,
    Uint8List bytes,
    String mimeType,
  ) async {
    await _client.storage.from('posts').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );
    return _client.storage.from('posts').getPublicUrl(path);
  }

  @override
  Future<PostModel> updatePost(
    String postId, {
    required String caption,
  }) async {
    await _client
        .from('posts')
        .update({'caption': caption, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', postId);
    final response = await _client
        .from('posts')
        .select(_selectWithAuthor)
        .eq('id', postId)
        .single();
    return PostModel.fromMap(response);
  }

  @override
  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
  }

  @override
  Future<List<PostModel>> getPostsByIds(List<String> postIds) async {
    if (postIds.isEmpty) return [];
    final response = await _client
        .from('posts')
        .select(_selectWithAuthor)
        .inFilter('id', postIds);
    final posts = (response as List)
        .map((e) => PostModel.fromMap(e as Map<String, dynamic>))
        .toList();
    final order = {for (var i = 0; i < postIds.length; i++) postIds[i]: i};
    posts.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
    return posts;
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
