// SQL to run in Supabase SQL editor for profiles and posts setup.

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
''';
