// SQL to run in Supabase SQL editor to set up all tables, RLS policies, and storage buckets.

const String profilesTableSql = '''
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  display_name TEXT,
  bio TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
''';

// $$ is the PL/pgSQL dollar-quote delimiter; split across concatenation to avoid Dart interpolation.
const String profileTriggerSql =
    'CREATE OR REPLACE FUNCTION public.handle_new_user()\n'
    'RETURNS TRIGGER\n'
    'LANGUAGE plpgsql\n'
    "SECURITY DEFINER SET search_path = public\n"
    'AS \$\$ \n'
    'BEGIN\n'
    '  INSERT INTO public.profiles (id, username, created_at, updated_at)\n'
    "  VALUES (NEW.id, SPLIT_PART(NEW.email, '@', 1), NOW(), NOW())\n"
    '  ON CONFLICT (id) DO NOTHING;\n'
    '  RETURN NEW;\n'
    'END;\n'
    '\$\$;\n'
    '\n'
    'DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;\n'
    'CREATE TRIGGER on_auth_user_created\n'
    '  AFTER INSERT ON auth.users\n'
    '  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();\n';

const String postsTableSql = '''
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  caption TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
''';

const String likesTableSql = '''
CREATE TABLE IF NOT EXISTS likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);
''';

const String bookmarksTableSql = '''
CREATE TABLE IF NOT EXISTS bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);
''';

const String postImagesTableSql = '''
CREATE TABLE IF NOT EXISTS post_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  position INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
''';

const String commentsTableSql = '''
CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
''';

const String followsTableSql = '''
CREATE TABLE IF NOT EXISTS follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (follower_id, following_id),
  CHECK (follower_id <> following_id)
);
''';

// Run after enabling RLS on both tables.
const String rlsPoliciesSql = '''
-- ── Profiles ──────────────────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_all"
  ON profiles FOR SELECT USING (true);

CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE USING (auth.uid() = id);

-- ── Posts ─────────────────────────────────────────────────────────────────
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "posts_select_all"
  ON posts FOR SELECT USING (true);

CREATE POLICY "posts_insert_own"
  ON posts FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "posts_update_own"
  ON posts FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "posts_delete_own"
  ON posts FOR DELETE USING (auth.uid() = user_id);

-- ── Storage: avatars bucket ────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
  VALUES ('avatars', 'avatars', true)
  ON CONFLICT DO NOTHING;

CREATE POLICY "avatars_select_all"
  ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "avatars_insert_own"
  ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars_update_own"
  ON storage.objects FOR UPDATE USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── Storage: posts bucket ─────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
  VALUES ('posts', 'posts', true)
  ON CONFLICT DO NOTHING;

CREATE POLICY "posts_images_select_all"
  ON storage.objects FOR SELECT USING (bucket_id = 'posts');

CREATE POLICY "posts_images_insert_own"
  ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'posts'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── Likes ─────────────────────────────────────────────────────────────────
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "likes_select_all"
  ON likes FOR SELECT USING (true);

CREATE POLICY "likes_insert_own"
  ON likes FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "likes_delete_own"
  ON likes FOR DELETE USING (auth.uid() = user_id);

-- ── Bookmarks ─────────────────────────────────────────────────────────────
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bookmarks_select_own"
  ON bookmarks FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "bookmarks_insert_own"
  ON bookmarks FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "bookmarks_delete_own"
  ON bookmarks FOR DELETE USING (auth.uid() = user_id);

-- ── Post Images ───────────────────────────────────────────────────────────
ALTER TABLE post_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "post_images_select_all"
  ON post_images FOR SELECT USING (true);

CREATE POLICY "post_images_insert_own"
  ON post_images FOR INSERT WITH CHECK (
    auth.uid() = (SELECT user_id FROM posts WHERE id = post_id)
  );

CREATE POLICY "post_images_delete_own"
  ON post_images FOR DELETE USING (
    auth.uid() = (SELECT user_id FROM posts WHERE id = post_id)
  );

-- ── Comments ──────────────────────────────────────────────────────────────
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comments_select_all"
  ON comments FOR SELECT USING (true);

CREATE POLICY "comments_insert_own"
  ON comments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "comments_delete_own"
  ON comments FOR DELETE USING (
    auth.uid() = user_id
    OR auth.uid() = (SELECT user_id FROM posts WHERE id = post_id)
  );

-- ── Follows ───────────────────────────────────────────────────────────────
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "follows_select_all"
  ON follows FOR SELECT USING (true);

CREATE POLICY "follows_insert_own"
  ON follows FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "follows_delete_own"
  ON follows FOR DELETE USING (auth.uid() = follower_id);

-- ── Realtime publications ─────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE likes;
ALTER PUBLICATION supabase_realtime ADD TABLE comments;
ALTER PUBLICATION supabase_realtime ADD TABLE posts;
''';

const String notificationsTableSql = '''
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow', 'message')),
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

CREATE POLICY "notifications_delete_own"
  ON notifications FOR DELETE USING (auth.uid() = recipient_id);

ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
''';

const String storiesTableSql = '''
CREATE TABLE IF NOT EXISTS music_clips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  audio_url TEXT NOT NULL,
  cover_url TEXT,
  duration_seconds INT NOT NULL DEFAULT 30,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  music_clip_id UUID REFERENCES music_clips(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours')
);

CREATE TABLE IF NOT EXISTS story_views (
  story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  viewer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (story_id, viewer_id)
);

ALTER TABLE music_clips ENABLE ROW LEVEL SECURITY;
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "music_clips_select_all"
  ON music_clips FOR SELECT USING (true);

CREATE POLICY "stories_select_all"
  ON stories FOR SELECT USING (true);

CREATE POLICY "stories_insert_own"
  ON stories FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "stories_delete_own"
  ON stories FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "story_views_select_all"
  ON story_views FOR SELECT USING (true);

CREATE POLICY "story_views_insert_authenticated"
  ON story_views FOR INSERT WITH CHECK (auth.uid() = viewer_id);

-- Storage buckets
INSERT INTO storage.buckets (id, name, public)
  VALUES ('stories', 'stories', true)
  ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
  VALUES ('music', 'music', true)
  ON CONFLICT DO NOTHING;

CREATE POLICY "stories_images_select_all"
  ON storage.objects FOR SELECT USING (bucket_id = 'stories');

CREATE POLICY "stories_images_insert_own"
  ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'stories'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "music_files_select_all"
  ON storage.objects FOR SELECT USING (bucket_id = 'music');
''';

const String conversationsTableSql = '''
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  last_message_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conversation_participants (
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  body TEXT,
  shared_post_id UUID REFERENCES posts(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (body IS NOT NULL OR shared_post_id IS NOT NULL)
);

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE OR REPLACE FUNCTION private.is_conversation_participant(target_conversation_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS \$\$
  SELECT EXISTS (
    SELECT 1
    FROM conversation_participants
    WHERE conversation_id = target_conversation_id
      AND user_id = auth.uid()
  );
\$\$;

REVOKE ALL ON FUNCTION private.is_conversation_participant(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_conversation_participant(UUID) TO authenticated;

DROP POLICY IF EXISTS "conversations_select_participant" ON conversations;
DROP POLICY IF EXISTS "conversations_update_participant" ON conversations;
DROP POLICY IF EXISTS "participants_select_own" ON conversation_participants;
DROP POLICY IF EXISTS "participants_select_conversation_members" ON conversation_participants;
DROP POLICY IF EXISTS "messages_select_participant" ON messages;
DROP POLICY IF EXISTS "messages_insert_participant" ON messages;

CREATE POLICY "conversations_select_participant"
  ON conversations FOR SELECT USING (private.is_conversation_participant(id));

CREATE POLICY "conversations_insert_authenticated"
  ON conversations FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "conversations_update_participant"
  ON conversations FOR UPDATE USING (private.is_conversation_participant(id));

CREATE POLICY "participants_select_conversation_members"
  ON conversation_participants FOR SELECT USING (
    private.is_conversation_participant(conversation_id)
  );

CREATE POLICY "participants_insert_authenticated"
  ON conversation_participants FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "messages_select_participant"
  ON messages FOR SELECT USING (
    private.is_conversation_participant(conversation_id)
  );

CREATE POLICY "messages_insert_participant"
  ON messages FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND private.is_conversation_participant(conversation_id)
  );

ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;

-- Atomic "find-or-create conversation, then insert message" RPC.
-- Doing this in a single transaction eliminates the multi-HTTP-request
-- timing issues that caused message inserts to fail RLS validation when the
-- participant rows from a prior request weren't yet visible.
CREATE OR REPLACE FUNCTION public.send_direct_message(
  recipient_id UUID,
  message_body TEXT DEFAULT NULL,
  shared_post UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS \$\$
DECLARE
  sender UUID := auth.uid();
  conv_id UUID;
  inserted_message JSONB;
BEGIN
  IF sender IS NULL THEN
    RAISE EXCEPTION 'send_direct_message: not authenticated';
  END IF;
  IF sender = recipient_id THEN
    RAISE EXCEPTION 'send_direct_message: cannot message self';
  END IF;
  IF message_body IS NULL AND shared_post IS NULL THEN
    RAISE EXCEPTION 'send_direct_message: body or shared_post required';
  END IF;

  -- Find a 1:1 conversation already shared by both users.
  SELECT cp1.conversation_id INTO conv_id
  FROM conversation_participants cp1
  INNER JOIN conversation_participants cp2
    ON cp2.conversation_id = cp1.conversation_id
  INNER JOIN conversations c
    ON c.id = cp1.conversation_id
  WHERE cp1.user_id = sender
    AND cp2.user_id = recipient_id
  ORDER BY c.last_message_at DESC NULLS LAST
  LIMIT 1;

  -- Create the conversation + both participant rows in this same transaction
  -- if none exists. Subsequent statements see these rows immediately.
  IF conv_id IS NULL THEN
    INSERT INTO conversations (last_message_at)
    VALUES (NOW())
    RETURNING id INTO conv_id;

    INSERT INTO conversation_participants (conversation_id, user_id)
    VALUES (conv_id, sender), (conv_id, recipient_id);
  END IF;

  INSERT INTO messages (conversation_id, sender_id, body, shared_post_id)
  VALUES (conv_id, sender, message_body, shared_post)
  RETURNING jsonb_build_object(
    'id', id,
    'conversation_id', conversation_id,
    'sender_id', sender_id,
    'body', body,
    'shared_post_id', shared_post_id,
    'created_at', created_at
  ) INTO inserted_message;

  UPDATE conversations SET last_message_at = NOW() WHERE id = conv_id;

  RETURN jsonb_build_object(
    'conversation_id', conv_id,
    'message', inserted_message
  );
END;
\$\$;

REVOKE ALL ON FUNCTION public.send_direct_message(UUID, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_direct_message(UUID, TEXT, UUID) TO authenticated;
''';
