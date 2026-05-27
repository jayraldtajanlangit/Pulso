# Pulso Implementation Checklist vs PRD

**Last updated:** 2026-05-27
**Branch:** `feat/social-interactions`
**Status:** ~95% complete — all six PRD features implemented, 81 tests passing, only submission artifacts remain

---

## 1. User Registration & Login ✅ COMPLETE

- [x] Email/password signup via Supabase Auth
- [x] Email/password login with persistent session
- [x] Logout clears session and navigates to login
- [x] User-friendly error messages for invalid credentials / mismatched passwords
- [x] Profiles record auto-created on signup
- [x] Session persistence across app restarts
- [x] Riverpod AuthController with state management
- [x] **Dedicated SignUpScreen** with confirm-password validation

**Tests:** auth_service_test.dart, auth_controller_test.dart, widget_test.dart (sign-up flow)

---

## 2. User Profile with Avatar Upload ✅ COMPLETE

- [x] Editable profile screen (username, display name, bio)
- [x] Avatar image picker from device gallery
- [x] Avatar upload to Supabase Storage (avatars bucket)
- [x] Avatar URL stored in profiles table
- [x] CachedNetworkImage for avatar display
- [x] Profile visible to other users (public read via RLS)
- [x] ProfileRepository + ProfileController
- [x] EditProfileScreen with all keyed fields
- [x] Reusable **ProfileAvatar** widget used across feed, post detail, comments, edit profile

**Tests:** profile_controller_test.dart, profile_screen_test.dart, profile_avatar_test.dart

---

## 3. Post Feed with Image Upload ✅ COMPLETE

- [x] Authenticated user can create a post with caption and image
- [x] Image uploaded to Supabase Storage (posts bucket)
- [x] URL stored in posts table
- [x] Feed displays ALL posts in reverse-chronological order
- [x] Each post card shows: avatar, username, image, caption, like count, comment count
- [x] **Pagination** — `getFeed(limit, offset)`, default page size 10
- [x] **Infinite scroll** — `loadMoreFeed()` triggered when scrolled within 400px of bottom
- [x] Footer shows loader, "You're all caught up", or empty
- [x] Pull-to-refresh resets and reloads feed
- [x] Posts joined with profile data in a single query (no N+1)

**Tests:** post_controller_test.dart, post_creation_screen_test.dart

---

## 4. Likes / Reactions ✅ COMPLETE

- [x] **likes** table in Supabase (id, post_id, user_id, created_at, UNIQUE constraint)
- [x] **LikeModel** class
- [x] **LikeRepository** — toggleLike, isLikedByUser, getLikeCount, getLikeCountsForPosts, getLikedPostIdsForUser, subscribeToLikes
- [x] **LikeController** — optimistic toggle, batch load, realtime subscribe with auto-dispose
- [x] **likeRepositoryProvider** + **likeControllerProvider**
- [x] **LikeButton** widget + **LikeCountText** widget
- [x] Real-time like count via Supabase Realtime (`posts_likes` channel)
- [x] Like button reflects current user's filled/unfilled state
- [x] UNIQUE constraint at DB level prevents double-likes
- [x] RLS policies: likes_select_authenticated, likes_insert_own, likes_delete_own

**Tests:** like_repository_test.dart (8 tests), like_button_test.dart (2 tests)

---

## 5. Comments ✅ COMPLETE

- [x] **comments** table in Supabase (id, post_id, user_id, body, created_at)
- [x] **CommentModel** class with joined profile fields
- [x] **CommentRepository** — fetchComments (with profile join), addComment, deleteComment, getCommentCount, getCommentCountsForPosts, subscribeToComments
- [x] **CommentController** — per-post threads, optimistic add/delete, per-thread realtime subscription
- [x] **commentRepositoryProvider** + **commentControllerProvider**
- [x] **CommentList** widget — author avatar, username, body, relative time
- [x] **CommentInput** widget — full backend integration via controller
- [x] Real-time comment list via Supabase Realtime (`post_comments_<postId>` filtered channel)
- [x] Post owner OR comment author can delete (matches RLS)
- [x] RLS policies: comments_select_authenticated, comments_insert_authenticated, comments_delete_post_owner_or_author

**Tests:** comment_repository_test.dart (7 tests), comment_list_test.dart (4 tests), comment_input_test.dart (3 tests)

---

## 6. Follow / Unfollow ✅ COMPLETE

- [x] **follows** table in Supabase (id, follower_id, following_id, created_at, UNIQUE constraint)
- [x] **FollowModel** class
- [x] **FollowRepository** — toggleFollow, follow, unfollow, isFollowing, getFollowerCount, getFollowingCount, getFollowingIds, getFollowerIds
- [x] **FollowController** — optimistic toggle with self-follow guard, follower/following stats, pending state
- [x] **followRepositoryProvider** + **followControllerProvider**
- [x] **FollowButton** widget — hides on own profile, Follow ↔ Following toggle
- [x] Profile screen shows live follower / following counts
- [x] RLS policies: follows_select_authenticated, follows_insert_own, follows_delete_own

**Tests:** follow_repository_test.dart (9 tests), follow_button_test.dart (3 tests)

---

## Technical Requirements ✅

### Riverpod State Management ✅
- [x] All 6 controller providers (auth, profile, post, like, comment, follow)
- [x] All 6 repository providers
- [x] Services providers (image picker)
- [x] Supabase client + config providers
- [x] **No raw setState for any Supabase-driven state**

### Supabase Realtime ✅
- [x] `posts_likes` channel — `LikeController.subscribe()`
- [x] `post_comments_<postId>` channel — `CommentController.loadComments()`
- [x] Auto-unsubscribe on dispose via `ref.onDispose` (guarded against uninitialized Supabase in tests)

### Storage Buckets ✅
- [x] `avatars` bucket (public)
- [x] `posts` bucket (public)
- [x] Storage RLS policies (select all, insert own folder)

### Row Level Security ✅ ALL 9 POLICIES ACTIVE

| Table | Policies |
|---|---|
| likes | select_authenticated, insert_own, delete_own |
| comments | select_authenticated, insert_authenticated, delete_post_owner_or_author |
| follows | select_authenticated, insert_own, delete_own |

*Plus existing profiles + posts policies.*

---

## Testing ✅ 81 / 81 PASSING

| Test file | Tests | Covers |
|---|---|---|
| supabase_config_test.dart | 2 | Config presence |
| auth_service_test.dart | 6 | AuthService.signUp/signIn/signOut |
| auth_controller_test.dart | — (pre-existing) | AuthController |
| post_controller_test.dart | 6 | PostController + feed loading |
| post_creation_screen_test.dart | 3 | Create post UI |
| profile_controller_test.dart | — (pre-existing) | ProfileController |
| profile_screen_test.dart | 6 | EditProfileScreen (rewritten) |
| widget_test.dart | 6 | App shell + sign-in/sign-up flows |
| **like_repository_test.dart** | **8** | **LikeRepository contract + controller integration** |
| **comment_repository_test.dart** | **7** | **CommentRepository contract + controller integration** |
| **follow_repository_test.dart** | **9** | **FollowRepository contract + controller integration** |
| **profile_avatar_test.dart** | **4** | **ProfileAvatar fallback + image rendering** |
| **like_button_test.dart** | **2** | **LikeButton toggle behavior** |
| **follow_button_test.dart** | **3** | **FollowButton states + self-hide** |
| **comment_list_test.dart** | **4** | **CommentList rendering + delete permissions** |
| **comment_input_test.dart** | **3** | **CommentInput submit behavior** |

**Total: 81 tests passing, 0 failing.**

---

## Submission Artifacts ⚠️ TODO

| Artifact | Status |
|---|---|
| 1. GitHub repository | ✅ (active branch: feat/social-interactions) |
| 2. Supabase schema export | ❌ Not yet captured |
| 3. Screen recording (3-10 min) | ❌ Not yet recorded |
| 4. Developer reflection journal (500+ words) | ❌ Not yet written |
| 5. RLS policy documentation | ❌ Not yet written |

---

## Estimated Grade (PRD Rubric)

| Category | Max | Earned | Status |
|---|---:|---:|---|
| 1. Authentication & Session | 15 | **15** | ✅ Full credit |
| 2. Database & CRUD | 15 | **15** | ✅ All 5 tables, FK relationships, no orphans |
| 3. Realtime Updates | 15 | **15** | ✅ 2 channels live, proper dispose |
| 4. Storage & Uploads | 10 | **10** | ✅ Both buckets working |
| 5. RLS Policies | 15 | **15** | ✅ All 9 + storage policies active |
| 6. Riverpod State Mgmt | 10 | **10** | ✅ Consistent throughout |
| 7. Testing | 15 | **15** | ✅ 81 tests, exceeds rubric requirements |
| 8. Submission Artifacts | 5 | **1** | ❌ Repo only (4 missing) |
| **TOTAL** | **100** | **~96** | |

*Submission Artifacts is the only outstanding category. Once those 4 deliverables are submitted, the project earns full credit.*
