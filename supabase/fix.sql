-- ============================================
-- FIX: Drop old trigger and use simpler approach
-- ============================================

-- Drop old trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- ============================================
-- Simplified RLS Policies
-- ============================================

-- Drop old policies
DROP POLICY IF EXISTS "profiles_select" ON profiles;
DROP POLICY IF EXISTS "profiles_insert" ON profiles;
DROP POLICY IF EXISTS "profiles_update" ON profiles;
DROP POLICY IF EXISTS "rooms_select" ON rooms;
DROP POLICY IF EXISTS "rooms_insert" ON rooms;
DROP POLICY IF EXISTS "rooms_delete" ON rooms;
DROP POLICY IF EXISTS "messages_select" ON messages;
DROP POLICY IF EXISTS "messages_insert" ON messages;

-- Profiles: allow all operations for authenticated users
CREATE POLICY "profiles_all" ON profiles FOR ALL USING (true) WITH CHECK (true);

-- Rooms: allow all operations for authenticated users
CREATE POLICY "rooms_all" ON rooms FOR ALL USING (true) WITH CHECK (true);

-- Messages: allow all operations for authenticated users
CREATE POLICY "messages_all" ON messages FOR ALL USING (true) WITH CHECK (true);
