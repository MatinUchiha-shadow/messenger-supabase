-- Expand role system to 6 ranks (Discord-style)
-- owner > admin > mod > vip > active > user

-- 1. Drop the old CHECK constraint and add new one
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check 
  CHECK (role IN ('owner', 'admin', 'mod', 'vip', 'active', 'user'));

-- 2. Update RLS policies that reference role
DROP POLICY IF EXISTS "rooms_delete" ON rooms;
CREATE POLICY "rooms_delete" ON rooms FOR DELETE 
  USING (auth.uid() = created_by OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('owner', 'admin', 'mod')));

DROP POLICY IF EXISTS "sound_effects_delete" ON sound_effects;
CREATE POLICY "sound_effects_delete" ON sound_effects FOR DELETE 
  USING (auth.uid() = user_id OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('owner', 'admin', 'mod')));

DROP POLICY IF EXISTS "sound_effects_update" ON sound_effects;
CREATE POLICY "sound_effects_update" ON sound_effects FOR UPDATE 
  USING (auth.uid() = user_id OR auth.uid() IN (SELECT id FROM profiles WHERE role IN ('owner', 'admin', 'mod')));

-- 3. Allow owner to update anyone's role
DROP POLICY IF EXISTS "profiles_update_role" ON profiles;
CREATE POLICY "profiles_update_role" ON profiles FOR UPDATE 
  USING (auth.uid() = id OR auth.uid() IN (SELECT id FROM profiles WHERE role = 'owner'));
