-- Add banner_url column for Discord-style profile banners
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS banner_url TEXT;

-- Allow users to update their own banner
DROP POLICY IF EXISTS "profiles_update_banner" ON profiles;
CREATE POLICY "profiles_update_banner" ON profiles FOR UPDATE USING (auth.uid() = id);
