-- ============================================
-- Supabase Schema for Messenger Platform
-- ============================================

-- Enable Row Level Security
ALTER DATABASE postgres SET "app.jwt_secret" TO 'your-jwt-secret';

-- ============================================
-- 1. Users Table (extends Supabase Auth)
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT,
  role TEXT DEFAULT 'user' CHECK(role IN ('owner', 'admin', 'user')),
  avatar_url TEXT,
  status TEXT DEFAULT 'offline',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. Rooms Table
-- ============================================
CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT DEFAULT 'text' CHECK(type IN ('text', 'voice')),
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. Messages Table
-- ============================================
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id),
  type TEXT DEFAULT 'text' CHECK(type IN ('text', 'image', 'voice', 'file')),
  content TEXT,
  file_url TEXT,
  file_name TEXT,
  file_size BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 4. Room Members Table
-- ============================================
CREATE TABLE IF NOT EXISTS room_members (
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (room_id, user_id)
);

-- ============================================
-- 5. Indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_messages_room_id ON messages(room_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_room_members_user_id ON room_members(user_id);

-- ============================================
-- 6. Row Level Security Policies
-- ============================================

-- Profiles: everyone can read, only owner can update
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles are viewable by everyone" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Rooms: everyone can read, admins can create/delete
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Rooms are viewable by everyone" ON rooms
  FOR SELECT USING (true);

CREATE POLICY "Admins can create rooms" ON rooms
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('owner', 'admin'))
  );

CREATE POLICY "Admins can delete rooms" ON rooms
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('owner', 'admin'))
  );

-- Messages: everyone can read, authenticated users can create
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Messages are viewable by everyone" ON messages
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create messages" ON messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Room Members: everyone can read, users can join/leave
ALTER TABLE room_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Room members are viewable by everyone" ON room_members
  FOR SELECT USING (true);

CREATE POLICY "Users can join rooms" ON room_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave rooms" ON room_members
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- 7. Functions
-- ============================================

-- Function to create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name, role)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'username',
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'username'),
    CASE 
      WHEN (SELECT COUNT(*) FROM profiles) = 0 THEN 'owner'
      ELSE 'user'
    END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 8. Insert Default Rooms
-- ============================================
INSERT INTO rooms (name, type) VALUES
  ('general', 'text'),
  ('random', 'text'),
  ('Voice Lounge', 'voice')
ON CONFLICT DO NOTHING;

-- ============================================
-- 9. Enable Realtime
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
