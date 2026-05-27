# Notifications, DM, and Stories — Design Spec
**Date:** 2026-05-27  
**Build order:** Notifications → DM → Stories

---

## 1. Notifications

### Goal
Show users real-time alerts for likes, comments, new followers, and incoming DMs via a bell icon in the Feed AppBar.

### Data Model

**Table: `notifications`**

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `recipient_id` | UUID FK → profiles | who receives the notification |
| `actor_id` | UUID FK → profiles | who triggered it |
| `type` | text | `'like'` `'comment'` `'follow'` `'message'` |
| `post_id` | UUID FK → posts, nullable | set for like/comment |
| `read` | boolean, default false | |
| `created_at` | timestamptz | |

RLS: users can only read rows where `recipient_id = auth.uid()`. Users can insert rows (app creates notifications on actions). Users can update their own rows (mark read).

### Notification Creation
Notifications are inserted from the app layer (not DB triggers) whenever a like, comment, or follow action succeeds in its controller. DM notifications are inserted when a message is sent (built in Phase 2).

### UI
- Bell icon in FeedScreen AppBar with a red badge showing unread count
- Tapping bell pushes `NotificationsScreen` via `Navigator.push`
- **NotificationsScreen:** flat chronological list
  - Each row: actor avatar, action text (e.g. "juan_dela liked your post"), post thumbnail (for like/comment), relative timestamp
  - Unread rows: colored left border (`colorScheme.primary`)
  - Follow notifications: inline "Follow Back" button
  - Message notifications: navigate to conversation on tap
- All notifications marked read when screen opens (bulk update)
- Realtime: subscribe to `INSERT` on `notifications` filtered by `recipient_id = current user`

### New Code Units
```
lib/notification/notification_model.dart
lib/notification/notification_repository.dart   — fetch list, unread count, mark all read, realtime subscribe
lib/notification/notification_controller.dart   — NotifierProvider
lib/providers/notification_providers.dart
lib/screens/notifications_screen.dart
```

---

## 2. Direct Messages (DM)

### Goal
Users can share posts to other users via the send icon on post cards. Conversations support full text chat with shared post previews. Instagram-style UI.

### Data Model

**Table: `conversations`**

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `created_at` | timestamptz | |
| `last_message_at` | timestamptz | updated on each new message, used for inbox sorting |

**Table: `conversation_participants`**

| Column | Type | Notes |
|---|---|---|
| `conversation_id` | UUID FK → conversations | |
| `user_id` | UUID FK → profiles | |
| Unique on `(conversation_id, user_id)` | | |

**Table: `messages`**

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `conversation_id` | UUID FK → conversations | |
| `sender_id` | UUID FK → profiles | |
| `body` | text, nullable | plain text; null if this is a post share |
| `shared_post_id` | UUID FK → posts, nullable | set when sharing a post |
| `created_at` | timestamptz | |

RLS: users can only read/write messages and conversations they participate in (via `conversation_participants`).

### Send Flow (from post card)
1. User taps send icon on a post card
2. `UserPickerModal` appears — searchable list of followed users
3. User picks a recipient
4. App queries `conversation_participants` to find an existing 1-on-1 conversation between the two users
5. If none exists: create `conversations` row + two `conversation_participants` rows
6. Insert `messages` row with `shared_post_id` set
7. Update `conversations.last_message_at`
8. Insert `notifications` row with `type='message'`
9. Navigate to `ConversationScreen`

### Navigation
- **Activity tab** in the bottom nav is renamed to **Messages** and renders `InboxScreen`
- Bell icon in AppBar → `NotificationsScreen` (pushed route) covers all activity alerts

### UI

**InboxScreen (Instagram-style)**
- AppBar: username + compose icon
- Conversation list: avatar, display name, last message preview, relative timestamp
- Unread conversations: bold name + unread dot

**ConversationScreen (Instagram-style)**
- AppBar: recipient avatar + username
- Chat bubbles: sent = primary color, right-aligned; received = gray, left-aligned
- Shared posts render as a card with image thumbnail inside the bubble
- Text input bar + send button at bottom
- Realtime: subscribe to `INSERT` on `messages` filtered by `conversation_id`

### New Code Units
```
lib/message/conversation_model.dart
lib/message/message_model.dart
lib/message/message_repository.dart    — find/create conversation, send, fetch messages, realtime subscribe
lib/message/message_controller.dart    — NotifierProvider
lib/providers/message_providers.dart
lib/screens/inbox_screen.dart
lib/screens/conversation_screen.dart
lib/widgets/user_picker_modal.dart
```

Post card gets the send icon restored with `onPressed` wired to `UserPickerModal`.

---

## 3. Stories

### Goal
Users can post image stories (with optional background music from a built-in clip library) that expire after 24 hours. Stories from followed users appear in a horizontal row at the top of the feed.

### Data Model

**Table: `stories`**

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | UUID FK → profiles | |
| `image_url` | text | stored in `stories` Supabase bucket |
| `music_clip_id` | UUID FK → music_clips, nullable | |
| `created_at` | timestamptz | |
| `expires_at` | timestamptz | `created_at + interval '24 hours'` |

**Table: `story_views`**

| Column | Type | Notes |
|---|---|---|
| `story_id` | UUID FK → stories | |
| `viewer_id` | UUID FK → profiles | |
| `viewed_at` | timestamptz | |
| Unique on `(story_id, viewer_id)` | | |

**Table: `music_clips`** *(seeded, not user-created)*

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `title` | text | |
| `artist` | text | |
| `audio_url` | text | stored in `music` Supabase bucket |
| `cover_url` | text, nullable | album art thumbnail |
| `duration_seconds` | int | |

### New Storage Buckets
- `stories` — public, stores uploaded story images
- `music` — public, stores pre-seeded audio clips

### Stories Row Logic
- Query active stories (`expires_at > now()`) from followed users + current user
- Group by user — one avatar per user even with multiple stories
- Avatar ring: primary gradient if any story is unseen, gray if all seen
- Own story tile always first; `+` button always visible (add another story)
- Restored as `_StoriesRow` widget in `FeedScreen` body above the feed list

### Story Viewer
- Full-screen black background
- Progress bars at top (one segment per story for that user, auto-advances every 5 seconds)
- Tap left half → previous story; tap right half → next story
- Header: avatar, username, relative time, close button
- Music bar at bottom if `music_clip_id` set: album art, title, artist, "♪ Playing"
- Audio plays via `audioplayers` package while story is visible, pauses on close
- Records a `story_views` row on first view
- Own stories show view count at bottom

### Story Creation
1. `StoryCreationScreen` opens from `+` button on own story tile
2. Image picker (gallery only) — shows preview
3. Optional music picker: scrollable list of `music_clips` with album art, title, artist, duration
4. Tapping a clip previews a short audio snippet; tap again to deselect
5. "Share Story" button: uploads image to `stories` bucket, inserts `stories` row
6. Returns to feed

### New Code Units
```
lib/story/story_model.dart
lib/story/music_clip_model.dart
lib/story/story_repository.dart    — fetch active stories, create story, record view, fetch music clips
lib/story/story_controller.dart    — NotifierProvider
lib/providers/story_providers.dart
lib/screens/story_viewer_screen.dart
lib/screens/story_creation_screen.dart
lib/widgets/stories_row.dart        — extracted from feed_screen.dart, now a proper widget file
```

New dependency: `audioplayers` for music playback.

---

## Summary

| Phase | Feature | New Tables | New Screens |
|---|---|---|---|
| 1 | Notifications | `notifications` | `NotificationsScreen` |
| 2 | DM | `conversations`, `conversation_participants`, `messages` | `InboxScreen`, `ConversationScreen` |
| 3 | Stories | `stories`, `story_views`, `music_clips` | `StoryViewerScreen`, `StoryCreationScreen` |

Each phase is independently shippable. Phase 2 depends on Phase 1 for DM notifications. Phase 3 is fully independent.
