# Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real-time notifications system that alerts users of likes, comments, and new followers via a badge bell icon in the Feed AppBar.

**Architecture:** A `notifications` Supabase table stores events created by the app layer (not DB triggers) whenever a like, comment, or follow succeeds. A `NotificationController` (Riverpod `NotifierProvider`) holds a flat list + unread count and subscribes to Realtime inserts. The bell icon in `FeedScreen` shows the badge; tapping it pushes `NotificationsScreen`.

**Tech Stack:** Flutter, Riverpod (NotifierProvider), Supabase (postgres + realtime), mocktail (tests already in pubspec)

---

### Task 1: SQL migration — notifications table

**Files:**
- Modify: `lib/database/sql_schema.dart`

- [ ] **Step 1: Add SQL constants to sql_schema.dart**

Append to the bottom of `lib/database/sql_schema.dart`:

```dart
const String notificationsTableSql = '''
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN (\'like\', \'comment\', \'follow\', \'message\')),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT USING (auth.uid() = recipient_id);

CREATE POLICY "notifications_insert_authenticated"
  ON notifications FOR INSERT WITH CHECK (auth.uid() = actor_id);

CREATE POLICY "notifications_update_own"
  ON notifications FOR UPDATE USING (auth.uid() = recipient_id);

ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
''';
```

- [ ] **Step 2: Run the SQL in Supabase**

Copy the contents of `notificationsTableSql` and run it in the Supabase SQL editor for your project. Confirm the `notifications` table appears in Table Editor.

- [ ] **Step 3: Commit**

```bash
git add lib/database/sql_schema.dart
git commit -m "feat: add notifications table SQL"
```

---

### Task 2: NotificationModel

**Files:**
- Create: `lib/notification/notification_model.dart`
- Create: `test/notification/notification_model_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/notification/notification_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pulso/notification/notification_model.dart';

void main() {
  group('NotificationModel.fromMap', () {
    test('parses all fields with joined actor and post', () {
      final map = {
        'id': 'n1',
        'recipient_id': 'r1',
        'actor_id': 'a1',
        'type': 'like',
        'post_id': 'p1',
        'read': false,
        'created_at': '2026-01-01T00:00:00.000Z',
        'actor': {'username': 'juan', 'avatar_url': 'https://example.com/av.jpg'},
        'post': {'image_url': 'https://example.com/img.jpg'},
      };

      final model = NotificationModel.fromMap(map);

      expect(model.id, 'n1');
      expect(model.recipientId, 'r1');
      expect(model.actorId, 'a1');
      expect(model.type, 'like');
      expect(model.postId, 'p1');
      expect(model.read, false);
      expect(model.actorUsername, 'juan');
      expect(model.actorAvatarUrl, 'https://example.com/av.jpg');
      expect(model.postImageUrl, 'https://example.com/img.jpg');
    });

    test('handles null post and actor joins gracefully', () {
      final map = {
        'id': 'n2',
        'recipient_id': 'r1',
        'actor_id': 'a1',
        'type': 'follow',
        'post_id': null,
        'read': true,
        'created_at': '2026-01-01T00:00:00.000Z',
        'actor': null,
        'post': null,
      };

      final model = NotificationModel.fromMap(map);

      expect(model.postId, isNull);
      expect(model.actorUsername, isNull);
      expect(model.postImageUrl, isNull);
      expect(model.read, true);
    });

    test('copyWith only changes read field', () {
      final original = NotificationModel.fromMap({
        'id': 'n1',
        'recipient_id': 'r1',
        'actor_id': 'a1',
        'type': 'like',
        'post_id': null,
        'read': false,
        'created_at': '2026-01-01T00:00:00.000Z',
        'actor': null,
        'post': null,
      });

      final updated = original.copyWith(read: true);

      expect(updated.read, true);
      expect(updated.id, original.id);
      expect(updated.type, original.type);
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/notification/notification_model_test.dart
```

Expected: error — `notification_model.dart` not found.

- [ ] **Step 3: Create notification_model.dart**

Create `lib/notification/notification_model.dart`:

```dart
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    this.postId,
    required this.read,
    required this.createdAt,
    this.actorUsername,
    this.actorAvatarUrl,
    this.postImageUrl,
  });

  final String id;
  final String recipientId;
  final String actorId;
  final String type; // 'like' | 'comment' | 'follow' | 'message'
  final String? postId;
  final bool read;
  final DateTime createdAt;
  final String? actorUsername;
  final String? actorAvatarUrl;
  final String? postImageUrl;

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final actor = map['actor'] as Map<String, dynamic>?;
    final post = map['post'] as Map<String, dynamic>?;
    return NotificationModel(
      id: map['id'] as String,
      recipientId: map['recipient_id'] as String,
      actorId: map['actor_id'] as String,
      type: map['type'] as String,
      postId: map['post_id'] as String?,
      read: map['read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      actorUsername: actor?['username'] as String?,
      actorAvatarUrl: actor?['avatar_url'] as String?,
      postImageUrl: post?['image_url'] as String?,
    );
  }

  NotificationModel copyWith({bool? read}) {
    return NotificationModel(
      id: id,
      recipientId: recipientId,
      actorId: actorId,
      type: type,
      postId: postId,
      read: read ?? this.read,
      createdAt: createdAt,
      actorUsername: actorUsername,
      actorAvatarUrl: actorAvatarUrl,
      postImageUrl: postImageUrl,
    );
  }
}
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
flutter test test/notification/notification_model_test.dart
```

Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/notification/notification_model.dart test/notification/notification_model_test.dart
git commit -m "feat: add NotificationModel with fromMap and copyWith"
```

---

### Task 3: NotificationRepository

**Files:**
- Create: `lib/notification/notification_repository.dart`
- Create: `test/notification/notification_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/notification/notification_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pulso/notification/notification_model.dart';
import 'package:pulso/notification/notification_repository.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  group('NotificationRepository contract', () {
    late MockNotificationRepository repo;

    setUp(() {
      repo = MockNotificationRepository();
    });

    test('fetchNotifications returns a list', () async {
      when(() => repo.fetchNotifications('user1'))
          .thenAnswer((_) async => []);

      final result = await repo.fetchNotifications('user1');
      expect(result, isA<List<NotificationModel>>());
    });

    test('markAllRead completes without error', () async {
      when(() => repo.markAllRead('user1')).thenAnswer((_) async {});

      await expectLater(repo.markAllRead('user1'), completes);
    });

    test('insertNotification completes without error', () async {
      when(() => repo.insertNotification(
            recipientId: any(named: 'recipientId'),
            actorId: any(named: 'actorId'),
            type: any(named: 'type'),
            postId: any(named: 'postId'),
          )).thenAnswer((_) async {});

      await expectLater(
        repo.insertNotification(
          recipientId: 'r1',
          actorId: 'a1',
          type: 'like',
          postId: 'p1',
        ),
        completes,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/notification/notification_repository_test.dart
```

Expected: error — `notification_repository.dart` not found.

- [ ] **Step 3: Create notification_repository.dart**

Create `lib/notification/notification_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationModel>> fetchNotifications(String userId);
  Future<void> markAllRead(String userId);
  Future<void> insertNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? postId,
  });
  RealtimeChannel subscribe(
    String userId,
    void Function(NotificationModel) onNew,
  );
}

class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, actor:profiles!actor_id(username, avatar_url), post:posts!post_id(image_url)';

  @override
  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select(_select)
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((row) => NotificationModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('recipient_id', userId)
        .eq('read', false);
  }

  @override
  Future<void> insertNotification({
    required String recipientId,
    required String actorId,
    required String type,
    String? postId,
  }) async {
    if (recipientId == actorId) return; // never notify yourself
    await _client.from('notifications').insert({
      'recipient_id': recipientId,
      'actor_id': actorId,
      'type': type,
      if (postId != null) 'post_id': postId,
    });
  }

  @override
  RealtimeChannel subscribe(
    String userId,
    void Function(NotificationModel) onNew,
  ) {
    return _client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) async {
            final id = payload.newRecord['id'] as String?;
            if (id == null) return;
            final row = await _client
                .from('notifications')
                .select(_select)
                .eq('id', id)
                .maybeSingle();
            if (row != null) onNew(NotificationModel.fromMap(row));
          },
        )
        .subscribe();
  }
}
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
flutter test test/notification/notification_repository_test.dart
```

Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/notification/notification_repository.dart test/notification/notification_repository_test.dart
git commit -m "feat: add NotificationRepository"
```

---

### Task 4: NotificationController + providers

**Files:**
- Create: `lib/notification/notification_controller.dart`
- Create: `lib/providers/notification_providers.dart`
- Create: `test/notification/notification_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/notification/notification_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pulso/notification/notification_controller.dart';
import 'package:pulso/notification/notification_model.dart';
import 'package:pulso/notification/notification_repository.dart';
import 'package:pulso/providers/notification_providers.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

NotificationModel _fakeNotification({bool read = false}) =>
    NotificationModel(
      id: 'n1',
      recipientId: 'user1',
      actorId: 'actor1',
      type: 'like',
      read: read,
      createdAt: DateTime.now(),
    );

void main() {
  late MockNotificationRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockNotificationRepository();
    container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('initial state has empty list and zero unread', () {
    final state = container.read(notificationControllerProvider);
    expect(state.notifications, isEmpty);
    expect(state.unreadCount, 0);
    expect(state.isLoading, false);
  });

  test('load fills notifications and counts unread', () async {
    when(() => mockRepo.fetchNotifications('user1')).thenAnswer(
      (_) async => [_fakeNotification(read: false), _fakeNotification(read: true)],
    );
    when(() => mockRepo.subscribe(any(), any())).thenReturn(
      // Return a fake channel — just needs to not crash
      _FakeChannel(),
    );

    await container
        .read(notificationControllerProvider.notifier)
        .load('user1');

    final state = container.read(notificationControllerProvider);
    expect(state.notifications.length, 2);
    expect(state.unreadCount, 1);
  });

  test('markAllRead sets all notifications to read and resets unreadCount', () async {
    when(() => mockRepo.fetchNotifications('user1')).thenAnswer(
      (_) async => [_fakeNotification(read: false)],
    );
    when(() => mockRepo.subscribe(any(), any())).thenReturn(_FakeChannel());
    when(() => mockRepo.markAllRead('user1')).thenAnswer((_) async {});

    await container.read(notificationControllerProvider.notifier).load('user1');
    await container
        .read(notificationControllerProvider.notifier)
        .markAllRead('user1');

    final state = container.read(notificationControllerProvider);
    expect(state.unreadCount, 0);
    expect(state.notifications.every((n) => n.read), true);
  });
}

class _FakeChannel extends Fake implements RealtimeChannel {}
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/notification/notification_controller_test.dart
```

Expected: error — files not found.

- [ ] **Step 3: Create notification_controller.dart**

Create `lib/notification/notification_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/notification_providers.dart';
import 'notification_model.dart';
import 'notification_repository.dart';

class NotificationState {
  const NotificationState({
    required this.notifications,
    required this.unreadCount,
    this.isLoading = false,
  });

  const NotificationState.initial()
      : notifications = const [],
        unreadCount = 0,
        isLoading = false;

  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationController extends Notifier<NotificationState> {
  RealtimeChannel? _channel;

  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  NotificationState build() {
    ref.onDispose(() {
      final ch = _channel;
      if (ch == null) return;
      try {
        Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
      _channel = null;
    });
    return const NotificationState.initial();
  }

  Future<void> load(String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      final notifications = await _repository.fetchNotifications(userId);
      final unreadCount = notifications.where((n) => !n.read).length;
      state = NotificationState(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
      _subscribe(userId);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markAllRead(String userId) async {
    await _repository.markAllRead(userId);
    state = state.copyWith(
      notifications:
          state.notifications.map((n) => n.copyWith(read: true)).toList(),
      unreadCount: 0,
    );
  }

  void _subscribe(String userId) {
    if (_channel != null) return;
    _channel = _repository.subscribe(userId, (notification) {
      state = state.copyWith(
        notifications: [notification, ...state.notifications],
        unreadCount: state.unreadCount + 1,
      );
    });
  }
}
```

- [ ] **Step 4: Create notification_providers.dart**

Create `lib/providers/notification_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notification/notification_controller.dart';
import '../notification/notification_repository.dart';
import 'supabase_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) throw StateError('Supabase client not initialized');
  return SupabaseNotificationRepository(client);
});

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
```

- [ ] **Step 5: Run the test to confirm it passes**

```bash
flutter test test/notification/notification_controller_test.dart
```

Expected: All 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/notification/ lib/providers/notification_providers.dart test/notification/notification_controller_test.dart
git commit -m "feat: add NotificationController and providers"
```

---

### Task 5: Wire notifications into likes

**Files:**
- Modify: `lib/like/like_controller.dart`
- Modify: `lib/widgets/like_button.dart`
- Modify: `lib/widgets/post_card.dart`

- [ ] **Step 1: Add postOwnerId param to LikeController.toggle**

In `lib/like/like_controller.dart`, replace the `toggle` method signature and body:

```dart
Future<void> toggle({
  required String postId,
  required String currentUserId,
  String? postOwnerId,
}) async {
  final current = state.statusFor(postId);
  final optimistic = LikeStatus(
    isLiked: !current.isLiked,
    count: (current.count + (current.isLiked ? -1 : 1)).clamp(0, 1 << 31),
  );
  _setStatus(postId, optimistic);

  try {
    final nowLiked = await _repository.toggleLike(
      postId: postId,
      userId: currentUserId,
    );
    if (nowLiked != optimistic.isLiked) {
      await _refreshPost(postId, currentUserId);
    }
    if (nowLiked && postOwnerId != null && postOwnerId != currentUserId) {
      try {
        await ref.read(notificationRepositoryProvider).insertNotification(
          recipientId: postOwnerId,
          actorId: currentUserId,
          type: 'like',
          postId: postId,
        );
      } catch (_) {}
    }
  } catch (e) {
    _setStatus(postId, current);
    state = state.copyWith(errorMessage: e.toString());
  }
}
```

Also add the import at the top of `lib/like/like_controller.dart`:

```dart
import '../providers/notification_providers.dart';
```

- [ ] **Step 2: Add postOwnerId param to LikeButton**

In `lib/widgets/like_button.dart`, update the `LikeButton` class:

Replace the constructor and class fields:

```dart
class LikeButton extends ConsumerWidget {
  const LikeButton({
    super.key,
    required this.postId,
    this.postOwnerId,
    this.iconSize = 24,
    this.likedColor = Colors.red,
    this.unlikedColor,
    this.onTapDisabledMessage,
  });

  final String postId;
  final String? postOwnerId;
  final double iconSize;
  final Color likedColor;
  final Color? unlikedColor;
  final String? onTapDisabledMessage;
```

Replace the `onPressed` call inside `build`:

```dart
ref.read(likeControllerProvider.notifier).toggle(
  postId: postId,
  currentUserId: session.userId,
  postOwnerId: postOwnerId,
);
```

- [ ] **Step 3: Pass post.userId to LikeButton in PostCard**

In `lib/widgets/post_card.dart`, find the `LikeButton` usage in the actions row and update it:

```dart
LikeButton(postId: post.id, postOwnerId: post.userId),
```

- [ ] **Step 4: Verify app compiles**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/like/like_controller.dart lib/widgets/like_button.dart lib/widgets/post_card.dart
git commit -m "feat: insert like notification via LikeController"
```

---

### Task 6: Wire notifications into comments

**Files:**
- Modify: `lib/comment/comment_controller.dart`
- Modify: `lib/widgets/comment_input.dart`
- Modify: `lib/screens/post_detail_screen.dart`

- [ ] **Step 1: Add postOwnerId param to CommentController.addComment**

In `lib/comment/comment_controller.dart`, replace the `addComment` method signature and add the notification call after a successful insert. First add the import at the top:

```dart
import '../providers/notification_providers.dart';
```

Then replace the `addComment` method:

```dart
Future<void> addComment({
  required String postId,
  required String userId,
  required String body,
  String? postOwnerId,
}) async {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    _setThread(
      postId,
      state.threadFor(postId).copyWith(errorMessage: 'Comment cannot be empty.'),
    );
    return;
  }

  _setThread(
    postId,
    state.threadFor(postId).copyWith(isSubmitting: true, clearError: true),
  );
  try {
    final created = await _repository.addComment(
      postId: postId,
      userId: userId,
      body: trimmed,
    );
    final thread = state.threadFor(postId);
    final hasIt = thread.comments.any((c) => c.id == created.id);
    final next = hasIt ? thread.comments : [...thread.comments, created];
    _setThread(postId, thread.copyWith(isSubmitting: false, comments: next));
    _setCount(postId, next.length);

    if (postOwnerId != null && postOwnerId != userId) {
      try {
        await ref.read(notificationRepositoryProvider).insertNotification(
          recipientId: postOwnerId,
          actorId: userId,
          type: 'comment',
          postId: postId,
        );
      } catch (_) {}
    }
  } catch (e) {
    _setThread(
      postId,
      state.threadFor(postId).copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ),
    );
  }
}
```

- [ ] **Step 2: Add postOwnerId param to CommentInput**

In `lib/widgets/comment_input.dart`, update the constructor:

```dart
class CommentInput extends ConsumerStatefulWidget {
  const CommentInput({
    super.key,
    required this.postId,
    this.postOwnerId,
    this.currentUserAvatarUrl,
    this.currentUserDisplayName,
    this.hintText = 'Add a comment...',
  });

  final String postId;
  final String? postOwnerId;
  final String? currentUserAvatarUrl;
  final String? currentUserDisplayName;
  final String hintText;
```

Update the `_submit` method to pass `postOwnerId`:

```dart
await ref.read(commentControllerProvider.notifier).addComment(
  postId: widget.postId,
  userId: session.userId,
  body: text,
  postOwnerId: widget.postOwnerId,
);
```

- [ ] **Step 3: Pass post.userId to CommentInput in PostDetailScreen**

In `lib/screens/post_detail_screen.dart`, update `CommentInput`:

```dart
CommentInput(
  postId: widget.post.id,
  postOwnerId: widget.post.userId,
  currentUserAvatarUrl: currentProfile?.avatarUrl,
  currentUserDisplayName:
      currentProfile?.displayName ?? currentProfile?.username,
),
```

- [ ] **Step 4: Verify app compiles**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/comment/comment_controller.dart lib/widgets/comment_input.dart lib/screens/post_detail_screen.dart
git commit -m "feat: insert comment notification via CommentController"
```

---

### Task 7: Wire notifications into follows

**Files:**
- Modify: `lib/follow/follow_controller.dart`

- [ ] **Step 1: Add notification insert to FollowController.toggleFollow**

In `lib/follow/follow_controller.dart`, add the import at the top:

```dart
import '../providers/notification_providers.dart';
```

In `toggleFollow`, after `final nowFollowing = await _repository.toggleFollow(...)` succeeds, add the notification call. Replace the `try` block inside `toggleFollow`:

```dart
try {
  final nowFollowing = await _repository.toggleFollow(
    followerId: currentUserId,
    followingId: targetUserId,
  );
  if (nowFollowing != !wasFollowing) {
    await loadFollowState(
      currentUserId: currentUserId,
      targetUserId: targetUserId,
    );
    await loadStats(targetUserId);
  }
  if (nowFollowing) {
    try {
      await ref.read(notificationRepositoryProvider).insertNotification(
        recipientId: targetUserId,
        actorId: currentUserId,
        type: 'follow',
      );
    } catch (_) {}
  }
} catch (e) {
```

- [ ] **Step 2: Verify app compiles**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/follow/follow_controller.dart
git commit -m "feat: insert follow notification via FollowController"
```

---

### Task 8: Bell icon with unread badge in FeedScreen

**Files:**
- Modify: `lib/screens/feed_screen.dart`

- [ ] **Step 1: Add notification load on init**

In `lib/screens/feed_screen.dart`, add the import:

```dart
import '../providers/notification_providers.dart';
import 'notifications_screen.dart';
```

In `_initialLoad()`, after the existing Future.wait, add:

```dart
final userId = ref.read(authControllerProvider).session?.userId;
// ... existing code ...
if (userId != null) {
  ref.read(notificationControllerProvider.notifier).load(userId);
}
```

Replace `_initialLoad` in full:

```dart
Future<void> _initialLoad() async {
  if (_didInit) return;
  _didInit = true;
  final userId = ref.read(authControllerProvider).session?.userId;
  if (userId == null) return;

  try {
    ref.read(likeControllerProvider.notifier).subscribe(currentUserId: userId);
  } catch (_) {}

  await Future.wait([
    ref.read(postControllerProvider.notifier).loadFeed(),
    ref.read(followControllerProvider.notifier).loadFollowingIds(userId),
  ]);

  try {
    ref.read(notificationControllerProvider.notifier).load(userId);
  } catch (_) {}
}
```

- [ ] **Step 2: Restore bell icon with badge in AppBar actions**

In `lib/screens/feed_screen.dart`, replace `actions: const [],` with:

```dart
actions: [
  Stack(
    children: [
      IconButton(
        icon: const Icon(Icons.notifications_none),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NotificationsScreen(),
          ),
        ),
      ),
      Consumer(
        builder: (context, ref, _) {
          final unread = ref.watch(
            notificationControllerProvider
                .select((s) => s.unreadCount),
          );
          if (unread == 0) return const SizedBox.shrink();
          return Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ],
  ),
],
```

- [ ] **Step 3: Verify app compiles**

```bash
flutter analyze
```

Expected: no errors (NotificationsScreen doesn't exist yet — expected).

- [ ] **Step 4: Commit**

```bash
git add lib/screens/feed_screen.dart
git commit -m "feat: add notification bell with badge to FeedScreen AppBar"
```

---

### Task 9: NotificationsScreen

**Files:**
- Create: `lib/screens/notifications_screen.dart`

- [ ] **Step 1: Create notifications_screen.dart**

Create `lib/screens/notifications_screen.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notification/notification_model.dart';
import '../providers/auth_providers.dart';
import '../providers/follow_providers.dart';
import '../providers/notification_providers.dart';
import '../widgets/profile_avatar.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authControllerProvider).session?.userId;
      if (userId == null) return;
      ref.read(notificationControllerProvider.notifier).markAllRead(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: state.isLoading && state.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
              ? const Center(
                  child: Text(
                    'No notifications yet',
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                )
              : ListView.builder(
                  itemCount: state.notifications.length,
                  itemBuilder: (context, i) =>
                      _NotificationRow(notification: state.notifications[i]),
                ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final NotificationModel notification;

  String get _actionText {
    switch (notification.type) {
      case 'like':
        return 'liked your post';
      case 'comment':
        return 'commented on your post';
      case 'follow':
        return 'started following you';
      case 'message':
        return 'sent you a message';
      default:
        return 'interacted with you';
    }
  }

  String _relativeTime() {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final isUnread = !notification.read;

    return Container(
      decoration: isUnread
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: primary, width: 3),
              ),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isUnread ? 13 : 16, 10, 12, 10),
        child: Row(
          children: [
            ProfileAvatar(
              avatarUrl: notification.actorAvatarUrl,
              displayName: notification.actorUsername ?? '?',
              radius: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 13),
                  children: [
                    TextSpan(
                      text: '${notification.actorUsername ?? 'Someone'} ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: _actionText),
                    TextSpan(
                      text: '  ${_relativeTime()}',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (notification.type == 'follow')
              _FollowBackButton(actorId: notification.actorId)
            else if (notification.postImageUrl != null)
              _PostThumbnail(imageUrl: notification.postImageUrl!),
          ],
        ),
      ),
    );
  }
}

class _FollowBackButton extends ConsumerWidget {
  const _FollowBackButton({required this.actorId});

  final String actorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.session?.userId));
    if (currentUserId == null || currentUserId == actorId) {
      return const SizedBox.shrink();
    }

    final isFollowing = ref.watch(
      followControllerProvider.select((s) => s.isFollowing(actorId)),
    );

    return GestureDetector(
      onTap: () {
        ref.read(followControllerProvider.notifier).toggleFollow(
          currentUserId: currentUserId,
          targetUserId: actorId,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.transparent
              : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
          border: isFollowing
              ? Border.all(color: const Color(0xFFD1D5DB))
              : null,
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: isFollowing ? Colors.black87 : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PostThumbnail extends StatelessWidget {
  const _PostThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(color: Color(0xFFE5E7EB)),
        errorWidget: (_, __, ___) =>
            const ColoredBox(color: Color(0xFFE5E7EB)),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify app compiles and runs**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 3: Manual smoke test**

Run `flutter run`, log in, tap the bell icon in the Feed AppBar. Confirm:
- `NotificationsScreen` opens
- Empty state shows "No notifications yet"
- Like a post from another account → bell badge increments
- Open notifications → the like notification appears with actor name and post thumbnail
- Badge resets to 0 after opening screen

- [ ] **Step 4: Commit**

```bash
git add lib/screens/notifications_screen.dart
git commit -m "feat: add NotificationsScreen with real-time notifications list"
```
