import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/bookmark_providers.dart';
import 'bookmark_repository.dart';

class BookmarkState {
  const BookmarkState({required this.bookmarks, this.errorMessage});

  const BookmarkState.initial() : bookmarks = const {}, errorMessage = null;

  final Map<String, bool> bookmarks;
  final String? errorMessage;

  bool isBookmarked(String postId) => bookmarks[postId] ?? false;

  BookmarkState copyWith({
    Map<String, bool>? bookmarks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BookmarkState(
      bookmarks: bookmarks ?? this.bookmarks,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class BookmarkController extends Notifier<BookmarkState> {
  BookmarkRepository get _repository => ref.read(bookmarkRepositoryProvider);

  @override
  BookmarkState build() => const BookmarkState.initial();

  Future<void> loadForPosts({
    required List<String> postIds,
    required String userId,
  }) async {
    if (postIds.isEmpty) return;
    try {
      final bookmarked = await _repository.getBookmarkedPostIdsForUser(
        userId: userId,
        postIds: postIds,
      );
      final updated = Map<String, bool>.from(state.bookmarks);
      for (final id in postIds) {
        updated[id] = bookmarked.contains(id);
      }
      state = state.copyWith(bookmarks: updated, clearError: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> toggle({
    required String postId,
    required String userId,
  }) async {
    final current = state.isBookmarked(postId);
    _setBookmark(postId, !current);

    try {
      final nowBookmarked = await _repository.toggleBookmark(
        postId: postId,
        userId: userId,
      );
      if (nowBookmarked != !current) {
        _setBookmark(postId, nowBookmarked);
      }
      // Force the saved-posts list to re-fetch so the profile tab stays in sync.
      ref.invalidate(savedPostsProvider(userId));
    } catch (e) {
      _setBookmark(postId, current);
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void _setBookmark(String postId, bool value) {
    final updated = Map<String, bool>.from(state.bookmarks);
    updated[postId] = value;
    state = state.copyWith(bookmarks: updated, clearError: true);
  }
}
